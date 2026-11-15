/// Win32 window-management shim for opt-in custom decorations.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <dwmapi.h>

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif

extern "C" {

int fm_is_wayland(void) {
    return 0;
}

int fm_supports_custom(void *window) {
    return window != nullptr ? 1 : 0;
}

void fm_set_decorated(void *window, int decorated) {
    HWND hwnd = static_cast<HWND>(window);
    if (hwnd == nullptr) {
        return;
    }

    LONG_PTR style = GetWindowLongPtrW(hwnd, GWL_STYLE);
    if (decorated) {
        style |= WS_CAPTION;
    } else {
        style &= ~static_cast<LONG_PTR>(WS_CAPTION);
        style |= WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU;
    }
    SetWindowLongPtrW(hwnd, GWL_STYLE, style);
    SetWindowPos(
        hwnd,
        nullptr,
        0,
        0,
        0,
        0,
        SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
    );

    if (!decorated) {
        int preference = DWMWCP_ROUND;
        DwmSetWindowAttribute(
            hwnd,
            DWMWA_WINDOW_CORNER_PREFERENCE,
            &preference,
            sizeof(preference)
        );
    }
}

void fm_set_titlebar_height(void *window, int height) {
    (void)window;
    (void)height;
}

void fm_show_when_loaded(void *window) {
    (void)window;
}

void fm_minimize(void *window) {
    HWND hwnd = static_cast<HWND>(window);
    if (hwnd != nullptr) {
        ShowWindow(hwnd, SW_MINIMIZE);
    }
}

void fm_toggle_maximize(void *window) {
    HWND hwnd = static_cast<HWND>(window);
    if (hwnd == nullptr) {
        return;
    }
    ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
}

int fm_is_maximized(void *window) {
    HWND hwnd = static_cast<HWND>(window);
    return hwnd != nullptr && IsZoomed(hwnd) ? 1 : 0;
}

void fm_close_window(void *window) {
    HWND hwnd = static_cast<HWND>(window);
    if (hwnd != nullptr) {
        PostMessageW(hwnd, WM_CLOSE, 0, 0);
    }
}

void fm_begin_move(void *window) {
    HWND hwnd = static_cast<HWND>(window);
    if (hwnd == nullptr) {
        return;
    }
    ReleaseCapture();
    SendMessageW(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
}

void fm_begin_resize(void *window, int edge) {
    HWND hwnd = static_cast<HWND>(window);
    if (hwnd == nullptr) {
        return;
    }

    WPARAM hit = HTLEFT;
    switch (edge) {
        case 0: hit = HTTOP; break;
        case 1: hit = HTBOTTOM; break;
        case 2: hit = HTLEFT; break;
        case 3: hit = HTRIGHT; break;
        case 4: hit = HTTOPLEFT; break;
        case 5: hit = HTTOPRIGHT; break;
        case 6: hit = HTBOTTOMLEFT; break;
        case 7: hit = HTBOTTOMRIGHT; break;
        default: return;
    }
    ReleaseCapture();
    SendMessageW(hwnd, WM_NCLBUTTONDOWN, hit, 0);
}

} // extern "C"
