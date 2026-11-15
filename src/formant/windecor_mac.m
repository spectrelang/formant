/// AppKit window-management shim for opt-in custom decorations.
///
/// macOS keeps its native traffic lights. The titlebar itself becomes
/// transparent and the web content extends underneath it, while a local event
/// monitor turns the empty titlebar area into a native drag region.

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

static id g_monitor = nil;
static NSWindow *g_custom_window = nil;
static NSTimer *g_reveal_timer = nil;
static NSWindow *g_pending_window = nil;
static NSDate *g_reveal_deadline = nil;
static CGFloat g_titlebar_height = 47.0;

static void fm_install_monitor(void) {
    if (g_monitor != nil) {
        return;
    }
    g_monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown
                                                      handler:^NSEvent *(NSEvent *event) {
        NSWindow *window = [event window];
        if (window == nil || window != g_custom_window) {
            return event;
        }
        NSView *view = [window contentView];
        if (view == nil) {
            return event;
        }

        NSPoint point = [event locationInWindow];
        NSRect bounds = [view bounds];
        CGFloat traffic_light_width = 80.0;
        CGFloat action_area_width = 190.0;
        if (point.y >= NSHeight(bounds) - g_titlebar_height &&
            point.x >= traffic_light_width &&
            point.x <= NSWidth(bounds) - action_area_width) {
            if ([event clickCount] == 2) {
                [window zoom:nil];
            } else {
                [window performWindowDragWithEvent:event];
            }
            return nil;
        }
        return event;
    }];
}

static WKWebView *fm_find_webview(NSView *view) {
    if (view == nil) {
        return nil;
    }
    if ([view isKindOfClass:[WKWebView class]]) {
        return (WKWebView *)view;
    }
    for (NSView *subview in [view subviews]) {
        WKWebView *found = fm_find_webview(subview);
        if (found != nil) {
            return found;
        }
    }
    return nil;
}

static void fm_reveal_tick(NSTimer *timer) {
    if (g_pending_window == nil) {
        [timer invalidate];
        g_reveal_timer = nil;
        return;
    }

    WKWebView *web = fm_find_webview(g_pending_window.contentView);
    BOOL timed_out = g_reveal_deadline != nil && [g_reveal_deadline timeIntervalSinceNow] <= 0;
    if (web != nil && web.loading && !timed_out) {
        return;
    }

    [timer invalidate];
    g_reveal_timer = nil;
    NSWindow *window = g_pending_window;
    g_pending_window = nil;
    g_reveal_deadline = nil;
    [window makeKeyAndOrderFront:nil];
}

extern "C" {

int fm_is_wayland(void) {
    return 0;
}

int fm_supports_custom(void *window) {
    return window != nullptr ? 1 : 0;
}

void fm_set_decorated(void *window, int decorated) {
    NSWindow *native_window = (__bridge NSWindow *)window;
    if (native_window == nil) {
        return;
    }

    if (decorated) {
        native_window.styleMask &= ~NSWindowStyleMaskFullSizeContentView;
        native_window.titlebarAppearsTransparent = NO;
        native_window.titleVisibility = NSWindowTitleVisible;
        if (g_custom_window == native_window) {
            g_custom_window = nil;
        }
    } else {
        g_custom_window = native_window;
        native_window.styleMask |= NSWindowStyleMaskFullSizeContentView;
        native_window.titlebarAppearsTransparent = YES;
        native_window.titleVisibility = NSWindowTitleHidden;
        native_window.movableByWindowBackground = NO;
        if (@available(macOS 11.0, *)) {
            native_window.titlebarSeparatorStyle = NSWindowTitlebarSeparatorStyleNone;
        }
        fm_install_monitor();
    }
}

void fm_set_titlebar_height(void *window, int height) {
    (void)window;
    if (height > 0) {
        g_titlebar_height = (CGFloat)height;
    }
}

void fm_show_when_loaded(void *window) {
    NSWindow *native_window = (__bridge NSWindow *)window;
    if (native_window == nil) {
        return;
    }
    WKWebView *web = fm_find_webview(native_window.contentView);
    if (web == nil || !web.loading) {
        return;
    }

    if (@available(macOS 12.0, *)) {
        NSColor *background = native_window.backgroundColor;
        if (background != nil) {
            web.underPageBackgroundColor = background;
        }
    }

    g_pending_window = native_window;
    g_reveal_deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
    [native_window orderOut:nil];

    if (g_reveal_timer != nil) {
        [g_reveal_timer invalidate];
    }
    g_reveal_timer = [NSTimer scheduledTimerWithTimeInterval:0.016
                                                     repeats:YES
                                                       block:^(NSTimer *timer) {
        fm_reveal_tick(timer);
    }];
}

void fm_minimize(void *window) {
    NSWindow *native_window = (__bridge NSWindow *)window;
    if (native_window != nil) {
        [native_window miniaturize:nil];
    }
}

void fm_toggle_maximize(void *window) {
    NSWindow *native_window = (__bridge NSWindow *)window;
    if (native_window != nil) {
        [native_window zoom:nil];
    }
}

int fm_is_maximized(void *window) {
    NSWindow *native_window = (__bridge NSWindow *)window;
    return native_window != nil && native_window.isZoomed ? 1 : 0;
}

void fm_close_window(void *window) {
    NSWindow *native_window = (__bridge NSWindow *)window;
    if (native_window != nil) {
        [native_window performClose:nil];
    }
}

void fm_begin_move(void *window) {
    (void)window;
}

void fm_begin_resize(void *window, int edge) {
    (void)window;
    (void)edge;
}

} // extern "C"
