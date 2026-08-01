/*
 * quartz_helper_win.c — Windows Win32 API backend
 *
 * Compile (MSVC):
 *   cl /c ext/quartz_helper_win.c /Fo ext/quartz_helper.o
 *
 * Compile (MinGW):
 *   gcc -c ext/quartz_helper_win.c -o ext/quartz_helper.o
 *
 * Link:
 *   -lgdi32 -luser32 -lcomctl32
 */
#include "quartz_helper.h"

#ifndef _WIN32
#  error "This file is Windows-only. Do not compile on other platforms."
#endif

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdlib.h>
#include <string.h>

// ── Widget registry ────────────────────────────────────────────────────
// Most widgets are HWNDs.  We store widget_id → HWND.
// We also store HWND → widget_id via Windows window properties
// (SetProp/GetProp) so WndProc can find the widget_id.
// -----------------------------------------------------------------------

// Forward declaration
static LRESULT CALLBACK quartz_wnd_proc(HWND hwnd, UINT msg,
                                        WPARAM wParam, LPARAM lParam);

// The registered window class atom
static ATOM g_window_class = 0;

// Window class name for Quartz windows
static const char *QUARTZ_WND_CLASS = "QuartzWindow";

// Windows property atom for widget_id
static const char *PROP_WIDGET_ID = "QUARTZ_WID";

// Callback registry: widget_id → QuartzCallback
typedef struct CallbackEntry {
    int32_t        widget_id;
    QuartzCallback callback;
    struct CallbackEntry *next;
} CallbackEntry;

static CallbackEntry *g_callback_head = NULL;

// Widget ID counter (thread-safe via InterlockedIncrement)
static LONG g_next_id = 1;

// ── Helpers ────────────────────────────────────────────────────────────

static CallbackEntry* find_callback(int32_t widget_id) {
    CallbackEntry *e = g_callback_head;
    while (e) {
        if (e->widget_id == widget_id) return e;
        e = e->next;
    }
    return NULL;
}

static void set_callback(int32_t widget_id, QuartzCallback callback) {
    CallbackEntry *e = find_callback(widget_id);
    if (e) {
        e->callback = callback;
    } else if (callback) {
        e = (CallbackEntry*)malloc(sizeof(CallbackEntry));
        e->widget_id = widget_id;
        e->callback  = callback;
        e->next      = g_callback_head;
        g_callback_head = e;
    }
}

static void remove_callback(int32_t widget_id) {
    CallbackEntry **prev = &g_callback_head;
    while (*prev) {
        if ((*prev)->widget_id == widget_id) {
            CallbackEntry *dead = *prev;
            *prev = dead->next;
            free(dead);
            return;
        }
        prev = &(*prev)->next;
    }
}

static void register_window_class(HINSTANCE hInstance) {
    if (g_window_class) return;

    WNDCLASSEXA wc = {0};
    wc.cbSize        = sizeof(WNDCLASSEXA);
    wc.lpfnWndProc   = quartz_wnd_proc;
    wc.hInstance     = hInstance;
    wc.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.lpszClassName = QUARTZ_WND_CLASS;

    g_window_class = RegisterClassExA(&wc);
}

// ── Window procedure ───────────────────────────────────────────────────

static LRESULT CALLBACK quartz_wnd_proc(HWND hwnd, UINT msg,
                                         WPARAM wParam, LPARAM lParam) {
    switch (msg) {

    case WM_COMMAND: {
        // LOWORD(wParam) = control identifier (we set it to widget_id)
        int32_t widget_id = (int32_t)LOWORD(wParam);
        CallbackEntry *e = find_callback(widget_id);
        if (e && e->callback) {
            e->callback(widget_id);
        }
        return 0;
    }

    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;

    default:
        break;
    }

    return DefWindowProcA(hwnd, msg, wParam, lParam);
}

// =======================================================================
// Public API
// =======================================================================

void quartz_init(void) {
    HINSTANCE hInstance = GetModuleHandleA(NULL);
    register_window_class(hInstance);
}

void quartz_run(void) {
    MSG msg;
    while (GetMessageA(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }
}

void quartz_terminate(void) {
    PostQuitMessage(0);
}

// ── Window ─────────────────────────────────────────────────────────────

int32_t quartz_window_create(const char *title, int32_t width, int32_t height) {
    HINSTANCE hInstance = GetModuleHandleA(NULL);
    register_window_class(hInstance);

    int32_t wid = InterlockedIncrement(&g_next_id);

    // Calculate window rect from desired client area
    RECT rc = {0, 0, (LONG)width, (LONG)height};
    AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);

    HWND hwnd = CreateWindowExA(
        0,                       // extended style
        QUARTZ_WND_CLASS,
        title,
        WS_OVERLAPPEDWINDOW,     // standard window
        CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left,
        rc.bottom - rc.top,
        NULL,                    // no parent
        NULL,                    // no menu
        hInstance,
        NULL                     // no extra param
    );

    // Attach widget_id to the window via a property
    SetPropA(hwnd, PROP_WIDGET_ID, (HANDLE)(uintptr_t)wid);

    return wid;
}

void quartz_window_set_title(int32_t widget_id, const char *title) {
    HWND hwnd = FindWindowA(QUARTZ_WND_CLASS, NULL);
    if (hwnd) {
        int32_t found = (int32_t)(uintptr_t)GetPropA(hwnd, PROP_WIDGET_ID);
        if (found == widget_id) {
            SetWindowTextA(hwnd, title);
        }
    }
}

void quartz_window_show(int32_t widget_id) {
    HWND hwnd = FindWindowA(QUARTZ_WND_CLASS, NULL);
    if (hwnd) {
        int32_t found = (int32_t)(uintptr_t)GetPropA(hwnd, PROP_WIDGET_ID);
        if (found == widget_id) {
            ShowWindow(hwnd, SW_SHOW);
            UpdateWindow(hwnd);
        }
    }
}

// ── Button ─────────────────────────────────────────────────────────────

int32_t quartz_button_create(const char *title, int32_t x, int32_t y,
                              int32_t width, int32_t height) {
    HINSTANCE hInstance = GetModuleHandleA(NULL);
    int32_t wid = InterlockedIncrement(&g_next_id);

    HWND hwnd = CreateWindowExA(
        0,
        "BUTTON",
        title,
        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        x, y, (int)width, (int)height,
        NULL,                    // parent set later via set_parent
        (HMENU)(uintptr_t)wid,   // control ID = widget_id
        hInstance,
        NULL
    );

    SetPropA(hwnd, PROP_WIDGET_ID, (HANDLE)(uintptr_t)wid);

    return wid;
}

// ── Label ──────────────────────────────────────────────────────────────

int32_t quartz_label_create(const char *text, int32_t x, int32_t y,
                             int32_t width, int32_t height) {
    HINSTANCE hInstance = GetModuleHandleA(NULL);
    int32_t wid = InterlockedIncrement(&g_next_id);

    HWND hwnd = CreateWindowExA(
        0,
        "STATIC",
        text,
        WS_CHILD | WS_VISIBLE | SS_LEFT,
        x, y, (int)width, (int)height,
        NULL,
        (HMENU)(uintptr_t)wid,
        hInstance,
        NULL
    );

    SetPropA(hwnd, PROP_WIDGET_ID, (HANDLE)(uintptr_t)wid);

    return wid;
}

// ── Widget hierarchy ───────────────────────────────────────────────────

// Find an HWND by widget_id — linear scan is fine for small numbers.
static HWND find_hwnd(int32_t widget_id) {
    HWND hwnd = FindWindowA(QUARTZ_WND_CLASS, NULL);
    if (hwnd) {
        int32_t found = (int32_t)(uintptr_t)GetPropA(hwnd, PROP_WIDGET_ID);
        if (found == widget_id) return hwnd;
    }
    return NULL;
}

void quartz_widget_set_parent(int32_t child_id, int32_t parent_id) {
    HWND child  = find_hwnd(child_id);
    HWND parent = find_hwnd(parent_id);

    if (!child || !parent) return;

    SetParent(child, parent);
}

// ── Widget properties ──────────────────────────────────────────────────

void quartz_widget_set_text(int32_t widget_id, const char *text) {
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        SetWindowTextA(hwnd, text);
    }
}

void quartz_widget_set_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        set_callback(widget_id, callback);
    } else {
        remove_callback(widget_id);
    }
}
