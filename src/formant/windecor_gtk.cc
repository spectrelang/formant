/// GTK window-management shim for opt-in custom decorations.
///
/// GTK's move/resize drag helpers need a native button press. The webview
/// consumes pointer events, so we record the last press on the window and its
/// child and replay it when the HTML titlebar asks to start a drag.

#include <gtk/gtk.h>
#include <gdk/gdk.h>
#if GTK_MAJOR_VERSION >= 4
#include <webkit/webkit.h>
#else
#include <webkit2/webkit2.h>
#endif

#if defined(GDK_WINDOWING_WAYLAND)
#include <gdk/gdkwayland.h>
#endif

#if GTK_MAJOR_VERSION < 4
static GtkWidget *g_hooked_window = nullptr;
static GtkWidget *g_hooked_child = nullptr;
static GtkWindow *g_press_window = nullptr;
static guint g_press_button = 1;
static gdouble g_press_x = 0.0;
static gdouble g_press_y = 0.0;
static guint32 g_press_time = 0;
static gboolean g_press_valid = FALSE;

static gboolean fm_on_button_press(GtkWidget *, GdkEventButton *event, gpointer data) {
    if (event->type != GDK_BUTTON_PRESS || event->button == 0) {
        return FALSE;
    }
    g_press_window = GTK_WINDOW(data);
    g_press_button = event->button;
    g_press_x = event->x_root;
    g_press_y = event->y_root;
    g_press_time = event->time;
    g_press_valid = TRUE;
    return FALSE;
}

static void fm_hook_press(GtkWidget *window) {
    if (g_hooked_window != window) {
        g_hooked_window = window;
        gtk_widget_add_events(window, GDK_BUTTON_PRESS_MASK);
        g_signal_connect(window, "button-press-event", G_CALLBACK(fm_on_button_press), window);
    }

    GtkWidget *child = gtk_bin_get_child(GTK_BIN(window));
    if (child != nullptr && g_hooked_child != child) {
        g_hooked_child = child;
        gtk_widget_add_events(child, GDK_BUTTON_PRESS_MASK);
        g_signal_connect(child, "button-press-event", G_CALLBACK(fm_on_button_press), window);
    }
}

static gboolean fm_on_map(GtkWidget *widget, GdkEvent *event, gpointer data) {
    (void)event;
    (void)data;
    fm_hook_press(widget);
    return FALSE;
}

static void fm_on_destroy(GtkWidget *widget, gpointer data) {
    (void)widget;
    (void)data;
    g_hooked_window = nullptr;
    g_hooked_child = nullptr;
    g_press_window = nullptr;
    g_press_valid = FALSE;
}

static void fm_install_drag_support(GtkWidget *window) {
    if (g_hooked_window == window) {
        return;
    }
    g_signal_connect(window, "map-event", G_CALLBACK(fm_on_map), nullptr);
    g_signal_connect(window, "destroy", G_CALLBACK(fm_on_destroy), nullptr);
    fm_hook_press(window);
}
#endif

static GtkWidget *fm_window_child(GtkWidget *window) {
#if GTK_MAJOR_VERSION >= 4
    return gtk_window_get_child(GTK_WINDOW(window));
#else
    return gtk_bin_get_child(GTK_BIN(window));
#endif
}

static GdkRGBA fm_default_background(GtkWidget *window) {
    GdkRGBA color;
    color.red = 0.98f;
    color.green = 0.98f;
    color.blue = 0.98f;
    color.alpha = 1.0f;

    GtkStyleContext *context = gtk_widget_get_style_context(window);
    if (context != nullptr) {
        if (gtk_style_context_lookup_color(context, "theme_bg_color", &color)
            || gtk_style_context_lookup_color(context, "window_bg_color", &color)) {
            color.alpha = 1.0f;
            return color;
        }
    }

    GtkSettings *settings = gtk_settings_get_default();
    gboolean prefer_dark = FALSE;
    if (settings != nullptr) {
        g_object_get(settings, "gtk-application-prefer-dark-theme", &prefer_dark, NULL);
    }
    if (prefer_dark) {
        color.red = 0.14f;
        color.green = 0.14f;
        color.blue = 0.14f;
    }
    color.alpha = 1.0f;
    return color;
}

static void fm_reveal_window(GtkWidget *window, GtkWidget *view) {
    if (view != nullptr) {
        g_signal_handlers_disconnect_by_data(view, window);
    }
    if (window != nullptr) {
        gtk_window_present(GTK_WINDOW(window));
    }
}

static void fm_on_load_changed(WebKitWebView *view, WebKitLoadEvent load_event, gpointer data) {
    if (load_event == WEBKIT_LOAD_FINISHED) {
        fm_reveal_window(GTK_WIDGET(data), GTK_WIDGET(view));
    }
}

static gboolean fm_on_load_failed(
    WebKitWebView *view,
    WebKitLoadEvent load_event,
    gchar *failing_uri,
    GError *error,
    gpointer data
) {
    (void)load_event;
    (void)failing_uri;
    (void)error;
    fm_reveal_window(GTK_WIDGET(data), GTK_WIDGET(view));
    return FALSE;
}

static void fm_on_web_process_terminated(
    WebKitWebView *view,
    WebKitWebProcessTerminationReason reason,
    gpointer data
) {
    (void)reason;
    fm_reveal_window(GTK_WIDGET(data), GTK_WIDGET(view));
}

extern "C" {

int fm_is_wayland(void) {
#if defined(GDK_WINDOWING_WAYLAND)
    GdkDisplay *display = gdk_display_get_default();
    if (display != nullptr && GDK_IS_WAYLAND_DISPLAY(display)) {
        return 1;
    }
#endif
    return 0;
}

int fm_supports_custom(void *window) {
    if (window == nullptr) {
        return 0;
    }
#if GTK_MAJOR_VERSION >= 4
    return 0;
#else
    return fm_is_wayland() ? 0 : 1;
#endif
}

void fm_set_decorated(void *window, int decorated) {
    if (window == nullptr) {
        return;
    }
    GtkWindow *win = GTK_WINDOW(window);
    gtk_window_set_decorated(win, decorated ? TRUE : FALSE);
#if GTK_MAJOR_VERSION < 4
    if (!decorated) {
        fm_install_drag_support(GTK_WIDGET(win));
    }
#else
    (void)decorated;
#endif
}

void fm_set_titlebar_height(void *window, int height) {
    (void)window;
    (void)height;
}

void fm_show_when_loaded(void *window) {
    if (window == nullptr) {
        return;
    }
    GtkWidget *win = GTK_WIDGET(window);
    GtkWidget *child = fm_window_child(win);
    if (child == nullptr || !WEBKIT_IS_WEB_VIEW(child)) {
        return;
    }

    GdkRGBA background = fm_default_background(win);
    webkit_web_view_set_background_color(WEBKIT_WEB_VIEW(child), &background);

    if (!webkit_web_view_is_loading(WEBKIT_WEB_VIEW(child))) {
        gtk_window_present(GTK_WINDOW(win));
        return;
    }

    g_signal_connect(child, "load-changed", G_CALLBACK(fm_on_load_changed), win);
    g_signal_connect(child, "load-failed", G_CALLBACK(fm_on_load_failed), win);
    g_signal_connect(child, "web-process-terminated", G_CALLBACK(fm_on_web_process_terminated), win);
    gtk_widget_hide(win);
}

void fm_minimize(void *window) {
    if (window == nullptr) {
        return;
    }
    gtk_window_iconify(GTK_WINDOW(window));
}

void fm_toggle_maximize(void *window) {
    if (window == nullptr) {
        return;
    }
    GtkWindow *win = GTK_WINDOW(window);
    if (gtk_window_is_maximized(win)) {
        gtk_window_unmaximize(win);
    } else {
        gtk_window_maximize(win);
    }
}

int fm_is_maximized(void *window) {
    if (window == nullptr) {
        return 0;
    }
    return gtk_window_is_maximized(GTK_WINDOW(window)) ? 1 : 0;
}

void fm_close_window(void *window) {
    if (window == nullptr) {
        return;
    }
    gtk_window_close(GTK_WINDOW(window));
}

void fm_begin_move(void *window) {
#if GTK_MAJOR_VERSION < 4
    if (window == nullptr) {
        return;
    }
    if (g_press_valid && g_press_window == GTK_WINDOW(window)) {
        gtk_window_begin_move_drag(
            GTK_WINDOW(window),
            (gint)g_press_button,
            (gint)g_press_x,
            (gint)g_press_y,
            g_press_time
        );
        return;
    }

    GdkDisplay *display = gdk_display_get_default();
    GdkSeat *seat = display != nullptr ? gdk_display_get_default_seat(display) : nullptr;
    GdkDevice *pointer = seat != nullptr ? gdk_seat_get_pointer(seat) : nullptr;
    if (pointer != nullptr) {
        gint x = 0;
        gint y = 0;
        gdk_device_get_position(pointer, nullptr, &x, &y);
        gtk_window_begin_move_drag(
            GTK_WINDOW(window),
            1,
            x,
            y,
            GDK_CURRENT_TIME
        );
    }
#else
    (void)window;
#endif
}

void fm_begin_resize(void *window, int edge) {
#if GTK_MAJOR_VERSION < 4
    if (window == nullptr) {
        return;
    }
    GdkWindowEdge gdk_edge = GDK_WINDOW_EDGE_NORTH;
    switch (edge) {
        case 0: gdk_edge = GDK_WINDOW_EDGE_NORTH; break;
        case 1: gdk_edge = GDK_WINDOW_EDGE_SOUTH; break;
        case 2: gdk_edge = GDK_WINDOW_EDGE_WEST; break;
        case 3: gdk_edge = GDK_WINDOW_EDGE_EAST; break;
        case 4: gdk_edge = GDK_WINDOW_EDGE_NORTH_WEST; break;
        case 5: gdk_edge = GDK_WINDOW_EDGE_NORTH_EAST; break;
        case 6: gdk_edge = GDK_WINDOW_EDGE_SOUTH_WEST; break;
        case 7: gdk_edge = GDK_WINDOW_EDGE_SOUTH_EAST; break;
        default: return;
    }

    if (g_press_valid && g_press_window == GTK_WINDOW(window)) {
        gtk_window_begin_resize_drag(
            GTK_WINDOW(window),
            gdk_edge,
            (gint)g_press_button,
            (gint)g_press_x,
            (gint)g_press_y,
            g_press_time
        );
        return;
    }

    GdkDisplay *display = gdk_display_get_default();
    GdkSeat *seat = display != nullptr ? gdk_display_get_default_seat(display) : nullptr;
    GdkDevice *pointer = seat != nullptr ? gdk_seat_get_pointer(seat) : nullptr;
    if (pointer != nullptr) {
        gint x = 0;
        gint y = 0;
        gdk_device_get_position(pointer, nullptr, &x, &y);
        gtk_window_begin_resize_drag(
            GTK_WINDOW(window),
            gdk_edge,
            1,
            x,
            y,
            GDK_CURRENT_TIME
        );
    }
#else
    (void)window;
    (void)edge;
#endif
}

} // extern "C"
