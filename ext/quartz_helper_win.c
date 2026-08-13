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
#include <commdlg.h>
#include <stdio.h>
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

// Change callback registry: widget_id → QuartzCallback (for TextBox text changes)
static CallbackEntry *g_change_callback_head = NULL;

// Selection callback registry: widget_id → QuartzCallback (for ListBox selection changes)
static CallbackEntry *g_selection_callback_head = NULL;

// Toggle change callback registry: widget_id → QuartzCallback (for CheckBox/RadioButton)
static CallbackEntry *g_toggle_callback_head = NULL;

static CallbackEntry* find_change_callback(int32_t widget_id) {
    CallbackEntry *e = g_change_callback_head;
    while (e) {
        if (e->widget_id == widget_id) return e;
        e = e->next;
    }
    return NULL;
}

static void set_change_callback(int32_t widget_id, QuartzCallback callback) {
    CallbackEntry *e = find_change_callback(widget_id);
    if (e) {
        e->callback = callback;
    } else if (callback) {
        e = (CallbackEntry*)malloc(sizeof(CallbackEntry));
        e->widget_id = widget_id;
        e->callback  = callback;
        e->next      = g_change_callback_head;
        g_change_callback_head = e;
    }
}

static CallbackEntry* find_selection_callback(int32_t widget_id) {
    CallbackEntry *e = g_selection_callback_head;
    while (e) {
        if (e->widget_id == widget_id) return e;
        e = e->next;
    }
    return NULL;
}

static void set_selection_callback(int32_t widget_id, QuartzCallback callback) {
    CallbackEntry *e = find_selection_callback(widget_id);
    if (e) {
        e->callback = callback;
    } else if (callback) {
        e = (CallbackEntry*)malloc(sizeof(CallbackEntry));
        e->widget_id = widget_id;
        e->callback  = callback;
        e->next      = g_selection_callback_head;
        g_selection_callback_head = e;
    }
}

static CallbackEntry* find_toggle_callback(int32_t widget_id) {
    CallbackEntry *e = g_toggle_callback_head;
    while (e) {
        if (e->widget_id == widget_id) return e;
        e = e->next;
    }
    return NULL;
}

static void set_toggle_callback(int32_t widget_id, QuartzCallback callback) {
    CallbackEntry *e = find_toggle_callback(widget_id);
    if (e) {
        e->callback = callback;
    } else if (callback) {
        e = (CallbackEntry*)malloc(sizeof(CallbackEntry));
        e->widget_id = widget_id;
        e->callback  = callback;
        e->next      = g_toggle_callback_head;
        g_toggle_callback_head = e;
    }
}

// Text callback registry: widget_id → QuartzCallback (for ComboBox edit text changes)
static CallbackEntry *g_text_callback_head = NULL;

static CallbackEntry* find_text_callback(int32_t widget_id) {
    CallbackEntry *e = g_text_callback_head;
    while (e) {
        if (e->widget_id == widget_id) return e;
        e = e->next;
    }
    return NULL;
}

static void set_text_callback(int32_t widget_id, QuartzCallback callback) {
    CallbackEntry *e = find_text_callback(widget_id);
    if (e) {
        e->callback = callback;
    } else if (callback) {
        e = (CallbackEntry*)malloc(sizeof(CallbackEntry));
        e->widget_id = widget_id;
        e->callback  = callback;
        e->next      = g_text_callback_head;
        g_text_callback_head = e;
    }
}

// Widget ID counter (thread-safe via InterlockedIncrement)
static LONG g_next_id = 1;

// Simple HWND registry: widget_id → HWND
typedef struct HwndEntry {
    int32_t widget_id;
    HWND    hwnd;
    struct HwndEntry *next;
} HwndEntry;

static HwndEntry *g_hwnd_head = NULL;

static void register_hwnd(int32_t widget_id, HWND hwnd) {
    HwndEntry *e = (HwndEntry*)malloc(sizeof(HwndEntry));
    e->widget_id = widget_id;
    e->hwnd      = hwnd;
    e->next      = g_hwnd_head;
    g_hwnd_head  = e;
}

static HWND lookup_hwnd(int32_t widget_id) {
    HwndEntry *e = g_hwnd_head;
    while (e) {
        if (e->widget_id == widget_id) return e->hwnd;
        e = e->next;
    }
    return NULL;
}

// ComboBox widget registry: widget_id → HWND, plus a reverse HWND → widget_id
// lookup so WM_COMMAND can tell ComboBox notifications apart by handle.
typedef struct ComboBoxEntry {
    int32_t widget_id;
    HWND    hwnd;
    struct ComboBoxEntry *next;
} ComboBoxEntry;

static ComboBoxEntry *g_combobox_map = NULL;

static void register_combobox(int32_t widget_id, HWND hwnd) {
    ComboBoxEntry *e = (ComboBoxEntry*)malloc(sizeof(ComboBoxEntry));
    e->widget_id = widget_id;
    e->hwnd      = hwnd;
    e->next      = g_combobox_map;
    g_combobox_map = e;
}

static ComboBoxEntry* find_combobox_widget(int32_t widget_id) {
    ComboBoxEntry *e = g_combobox_map;
    while (e) {
        if (e->widget_id == widget_id) return e;
        e = e->next;
    }
    return NULL;
}

static ComboBoxEntry* find_combobox_by_hwnd(HWND hwnd) {
    ComboBoxEntry *e = g_combobox_map;
    while (e) {
        if (e->hwnd == hwnd) return e;
        e = e->next;
    }
    return NULL;
}

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
        WORD notification = HIWORD(wParam);
        int32_t widget_id = (int32_t)LOWORD(wParam);

        if (notification == EN_CHANGE) {
            // TextBox text changed
            CallbackEntry *e = find_change_callback(widget_id);
            if (e && e->callback) {
                e->callback(widget_id);
            }
        } else if (notification == LBN_SELCHANGE) {
            // ListBox selection changed
            CallbackEntry *e = find_selection_callback(widget_id);
            if (e && e->callback) {
                e->callback(widget_id);
            }
        } else if (notification == CBN_SELCHANGE) {
            // ComboBox selection changed — identify the widget via its HWND
            ComboBoxEntry *ce = find_combobox_by_hwnd((HWND)lParam);
            if (ce) {
                CallbackEntry *e = find_selection_callback(ce->widget_id);
                if (e && e->callback) {
                    e->callback(ce->widget_id);
                }
            }
        } else if (notification == CBN_EDITCHANGE) {
            // ComboBox edit text changed
            ComboBoxEntry *ce = find_combobox_by_hwnd((HWND)lParam);
            if (ce) {
                CallbackEntry *e = find_text_callback(ce->widget_id);
                if (e && e->callback) {
                    e->callback(ce->widget_id);
                }
            }
        } else if (notification == BN_CLICKED) {
            // Check toggle callback first (for CheckBox / RadioButton)
            CallbackEntry *te = find_toggle_callback(widget_id);
            if (te && te->callback) {
                te->callback(widget_id);
            } else {
                // Fall back to generic button callback
                CallbackEntry *e = find_callback(widget_id);
                if (e && e->callback) {
                    e->callback(widget_id);
                }
            }
        } else {
            // Other control notification — generic callback
            CallbackEntry *e = find_callback(widget_id);
            if (e && e->callback) {
                e->callback(widget_id);
            }
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
    register_hwnd(wid, hwnd);

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
    register_hwnd(wid, hwnd);

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
    register_hwnd(wid, hwnd);

    return wid;
}

// ── TextBox ────────────────────────────────────────────────────────────

int32_t quartz_textbox_create(const char *text, int32_t x, int32_t y,
                               int32_t width, int32_t height) {
    HINSTANCE hInstance = GetModuleHandleA(NULL);
    int32_t wid = InterlockedIncrement(&g_next_id);

    HWND hwnd = CreateWindowExA(
        WS_EX_CLIENTEDGE,
        "EDIT",
        text,
        WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
        x, y, (int)width, (int)height,
        NULL,                    // parent set later via set_parent
        (HMENU)(uintptr_t)wid,   // control ID = widget_id
        hInstance,
        NULL
    );

    SetPropA(hwnd, PROP_WIDGET_ID, (HANDLE)(uintptr_t)wid);
    register_hwnd(wid, hwnd);

    return wid;
}

const char* quartz_textbox_get_text(int32_t widget_id) {
    static char buffer[4096];
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        GetWindowTextA(hwnd, buffer, sizeof(buffer));
        return buffer;
    }
    return "";
}

void quartz_textbox_set_max_length(int32_t widget_id, int32_t max_length) {
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        SendMessageA(hwnd, EM_SETLIMITTEXT, (WPARAM)max_length, 0);
    }
}

void quartz_textbox_set_read_only(int32_t widget_id, int32_t read_only) {
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        SendMessageA(hwnd, EM_SETREADONLY, (WPARAM)(read_only ? TRUE : FALSE), 0);
    }
}

void quartz_textbox_set_placeholder(int32_t widget_id, const char* text) {
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        SendMessageA(hwnd, EM_SETCUEBANNER, TRUE, (LPARAM)text);
    }
}

void quartz_textbox_set_password_char(int32_t widget_id, char ch) {
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        SendMessageA(hwnd, EM_SETPASSWORDCHAR, (WPARAM)ch, 0);
        InvalidateRect(hwnd, NULL, TRUE);
    }
}

void quartz_textbox_set_change_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        set_change_callback(widget_id, callback);
    }
}

// ── Widget hierarchy ───────────────────────────────────────────────────

// Find an HWND by widget_id — linear scan is fine for small numbers.
static HWND find_hwnd(int32_t widget_id) {
    return lookup_hwnd(widget_id);
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

void quartz_widget_set_enabled(int32_t widget_id, int32_t enabled) {
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        EnableWindow(hwnd, enabled ? TRUE : FALSE);
    }
}

// ── ListBox ────────────────────────────────────────────────────────────

int32_t quartz_listbox_create(int32_t x, int32_t y,
                               int32_t width, int32_t height) {
    HINSTANCE hInstance = GetModuleHandleA(NULL);
    int32_t wid = InterlockedIncrement(&g_next_id);

    HWND hwnd = CreateWindowExA(
        0,
        "LISTBOX",
        "",
        WS_CHILD | WS_VISIBLE | LBS_NOTIFY | WS_VSCROLL | WS_BORDER,
        x, y, (int)width, (int)height,
        NULL,                    // parent set later via set_parent
        (HMENU)(uintptr_t)wid,   // control ID = widget_id
        hInstance,
        NULL
    );

    SetPropA(hwnd, PROP_WIDGET_ID, (HANDLE)(uintptr_t)wid);
    register_hwnd(wid, hwnd);

    return wid;
}

void quartz_listbox_add_item(int32_t widget_id, const char* text) {
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        SendMessageA(hwnd, LB_ADDSTRING, 0, (LPARAM)text);
    }
}

void quartz_listbox_remove_item(int32_t widget_id, int32_t index) {
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        SendMessageA(hwnd, LB_DELETESTRING, (WPARAM)index, 0);
    }
}

void quartz_listbox_clear(int32_t widget_id) {
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        SendMessageA(hwnd, LB_RESETCONTENT, 0, 0);
    }
}

int32_t quartz_listbox_get_selected_index(int32_t widget_id) {
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        LRESULT result = SendMessageA(hwnd, LB_GETCURSEL, 0, 0);
        return (result == LB_ERR) ? -1 : (int32_t)result;
    }
    return -1;
}

const char* quartz_listbox_get_selected_text(int32_t widget_id) {
    static char buffer[4096];
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        LRESULT index = SendMessageA(hwnd, LB_GETCURSEL, 0, 0);
        if (index != LB_ERR) {
            LRESULT len = SendMessageA(hwnd, LB_GETTEXTLEN, (WPARAM)index, 0);
            if (len > 0 && len < (LRESULT)sizeof(buffer)) {
                SendMessageA(hwnd, LB_GETTEXT, (WPARAM)index, (LPARAM)buffer);
                return buffer;
            }
        }
    }
    return NULL;
}

void quartz_listbox_set_selected_index(int32_t widget_id, int32_t index) {
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        SendMessageA(hwnd, LB_SETCURSEL, (WPARAM)index, 0);
    }
}

int32_t quartz_listbox_get_item_count(int32_t widget_id) {
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        LRESULT result = SendMessageA(hwnd, LB_GETCOUNT, 0, 0);
        return (result == LB_ERR) ? 0 : (int32_t)result;
    }
    return 0;
}

const char* quartz_listbox_get_item_text(int32_t widget_id, int32_t index) {
    static char buffer[4096];
    HWND hwnd = find_hwnd(widget_id);
    if (hwnd) {
        LRESULT len = SendMessageA(hwnd, LB_GETTEXTLEN, (WPARAM)index, 0);
        if (len > 0 && len < (LRESULT)sizeof(buffer)) {
            SendMessageA(hwnd, LB_GETTEXT, (WPARAM)index, (LPARAM)buffer);
            return buffer;
        }
    }
    return "";
}

void quartz_listbox_set_selection_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        set_selection_callback(widget_id, callback);
    }
}

// ── ComboBox ───────────────────────────────────────────────────────────

int32_t quartz_combobox_create(int32_t x, int32_t y,
                               int32_t w, int32_t h,
                               int32_t editable) {
    HINSTANCE hInstance = GetModuleHandleA(NULL);
    int32_t wid = InterlockedIncrement(&g_next_id);

    // Editable combo boxes get an edit control (CBS_DROPDOWN); non-editable
    // ones are selection-only (CBS_DROPDOWNLIST).
    DWORD style = WS_CHILD | WS_VISIBLE | WS_VSCROLL;
    style |= editable ? CBS_DROPDOWN : CBS_DROPDOWNLIST;

    HWND hwnd = CreateWindowExA(
        0,
        "COMBOBOX",
        "",
        style,
        x, y, (int)w, (int)h,
        NULL,                    // parent set later via set_parent
        (HMENU)(uintptr_t)wid,   // control ID = widget_id
        hInstance,
        NULL
    );

    SetPropA(hwnd, PROP_WIDGET_ID, (HANDLE)(uintptr_t)wid);
    register_hwnd(wid, hwnd);
    register_combobox(wid, hwnd);

    return wid;
}

void quartz_combobox_add_item(int32_t widget_id, const char* text) {
    ComboBoxEntry *ce = find_combobox_widget(widget_id);
    if (ce && ce->hwnd) {
        SendMessageA(ce->hwnd, CB_ADDSTRING, 0, (LPARAM)text);
    }
}

void quartz_combobox_remove_item(int32_t widget_id, int32_t index) {
    ComboBoxEntry *ce = find_combobox_widget(widget_id);
    if (ce && ce->hwnd) {
        SendMessageA(ce->hwnd, CB_DELETESTRING, (WPARAM)index, 0);
    }
}

void quartz_combobox_clear(int32_t widget_id) {
    ComboBoxEntry *ce = find_combobox_widget(widget_id);
    if (ce && ce->hwnd) {
        SendMessageA(ce->hwnd, CB_RESETCONTENT, 0, 0);
    }
}

int32_t quartz_combobox_get_item_count(int32_t widget_id) {
    ComboBoxEntry *ce = find_combobox_widget(widget_id);
    if (ce && ce->hwnd) {
        LRESULT result = SendMessageA(ce->hwnd, CB_GETCOUNT, 0, 0);
        return (result == CB_ERR) ? 0 : (int32_t)result;
    }
    return 0;
}

const char* quartz_combobox_get_item_text(int32_t widget_id, int32_t index) {
    static char buffer[4096];
    ComboBoxEntry *ce = find_combobox_widget(widget_id);
    if (ce && ce->hwnd) {
        LRESULT len = SendMessageA(ce->hwnd, CB_GETLBTEXTLEN, (WPARAM)index, 0);
        if (len > 0 && len < (LRESULT)sizeof(buffer)) {
            SendMessageA(ce->hwnd, CB_GETLBTEXT, (WPARAM)index, (LPARAM)buffer);
            return buffer;
        }
    }
    return "";
}

int32_t quartz_combobox_get_selected_index(int32_t widget_id) {
    ComboBoxEntry *ce = find_combobox_widget(widget_id);
    if (ce && ce->hwnd) {
        LRESULT result = SendMessageA(ce->hwnd, CB_GETCURSEL, 0, 0);
        return (result == CB_ERR) ? -1 : (int32_t)result;
    }
    return -1;
}

void quartz_combobox_set_selected_index(int32_t widget_id, int32_t index) {
    ComboBoxEntry *ce = find_combobox_widget(widget_id);
    if (ce && ce->hwnd) {
        SendMessageA(ce->hwnd, CB_SETCURSEL, (WPARAM)index, 0);
    }
}

const char* quartz_combobox_get_text(int32_t widget_id) {
    static char buffer[4096];
    ComboBoxEntry *ce = find_combobox_widget(widget_id);
    if (ce && ce->hwnd) {
        SendMessageA(ce->hwnd, WM_GETTEXT, (WPARAM)sizeof(buffer), (LPARAM)buffer);
        return buffer;
    }
    return "";
}

void quartz_combobox_set_text(int32_t widget_id, const char* text) {
    ComboBoxEntry *ce = find_combobox_widget(widget_id);
    if (ce && ce->hwnd) {
        // WM_SETTEXT writes the edit-control text on editable (CBS_DROPDOWN)
        // combo boxes. On selection-only (CBS_DROPDOWNLIST) combo boxes the
        // text is owned by the selection, so this is a documented no-op that
        // must not change the selection.
        SendMessageA(ce->hwnd, WM_SETTEXT, 0, (LPARAM)text);
    }
}

int32_t quartz_combobox_get_dropped_down(int32_t widget_id) {
    ComboBoxEntry *ce = find_combobox_widget(widget_id);
    if (ce && ce->hwnd) {
        return (int32_t)SendMessageA(ce->hwnd, CB_GETDROPPEDSTATE, 0, 0);
    }
    return 0;
}

void quartz_combobox_set_dropped_down(int32_t widget_id, int32_t dropped) {
    ComboBoxEntry *ce = find_combobox_widget(widget_id);
    if (ce && ce->hwnd) {
        SendMessageA(ce->hwnd, CB_SHOWDROPDOWN,
                     (WPARAM)(dropped ? TRUE : FALSE), 0);
    }
}

void quartz_combobox_set_selection_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        set_selection_callback(widget_id, callback);
    }
}

void quartz_combobox_set_text_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        set_text_callback(widget_id, callback);
    }
}

// ── CheckBox ───────────────────────────────────────────────────────────

int32_t quartz_checkbox_create(const char *title, int32_t x, int32_t y,
                                int32_t width, int32_t height) {
    HINSTANCE hInstance = GetModuleHandleA(NULL);
    int32_t wid = InterlockedIncrement(&g_next_id);

    HWND hwnd = CreateWindowExA(
        0,
        "BUTTON",
        title,
        WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
        x, y, (int)width, (int)height,
        NULL,                    // parent set later via set_parent
        (HMENU)(uintptr_t)wid,   // control ID = widget_id
        hInstance,
        NULL
    );

    SetPropA(hwnd, PROP_WIDGET_ID, (HANDLE)(uintptr_t)wid);
    register_hwnd(wid, hwnd);

    return wid;
}

// ── RadioButton ────────────────────────────────────────────────────────

int32_t quartz_radiobutton_create(const char *title, int32_t x, int32_t y,
                                   int32_t width, int32_t height) {
    HINSTANCE hInstance = GetModuleHandleA(NULL);
    int32_t wid = InterlockedIncrement(&g_next_id);

    HWND hwnd = CreateWindowExA(
        0,
        "BUTTON",
        title,
        WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON,
        x, y, (int)width, (int)height,
        NULL,                    // parent set later via set_parent
        (HMENU)(uintptr_t)wid,   // control ID = widget_id
        hInstance,
        NULL
    );

    SetPropA(hwnd, PROP_WIDGET_ID, (HANDLE)(uintptr_t)wid);
    register_hwnd(wid, hwnd);

    return wid;
}

// ── Toggle state (shared by CheckBox and RadioButton) ──────────────────

int32_t quartz_toggle_get_checked(int32_t widget_id) {
    HWND hwnd = lookup_hwnd(widget_id);
    if (hwnd) {
        LRESULT state = SendMessageA(hwnd, BM_GETCHECK, 0, 0);
        return (state == BST_CHECKED) ? 1 : 0;
    }
    return 0;
}

void quartz_toggle_set_checked(int32_t widget_id, int32_t checked) {
    HWND hwnd = lookup_hwnd(widget_id);
    if (!hwnd) return;

    int32_t current = quartz_toggle_get_checked(widget_id);
    if (current == checked) return; // no change, no event

    SendMessageA(hwnd, BM_SETCHECK,
                 checked ? BST_CHECKED : BST_UNCHECKED, 0);

    // BM_SETCHECK does not fire BN_CLICKED, so dispatch manually
    CallbackEntry *e = find_toggle_callback(widget_id);
    if (e && e->callback) {
        e->callback(widget_id);
    }
}

void quartz_toggle_set_change_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        set_toggle_callback(widget_id, callback);
    }
}

// ── File dialogs ───────────────────────────────────────────────────────

static char g_filter_buffer[2048];

static void build_filter_buffer(const char* quartz_filter) {
    g_filter_buffer[0] = '\0';
    if (!quartz_filter || !*quartz_filter) return;
    int qi = 0, bi = 0;
    while (quartz_filter[qi] && bi + 2 < (int)sizeof(g_filter_buffer)) {
        char c = quartz_filter[qi++];
        if (c == '|') {
            g_filter_buffer[bi++] = '\0';
        } else {
            g_filter_buffer[bi++] = c;
        }
    }
    g_filter_buffer[bi++] = '\0';
    g_filter_buffer[bi++] = '\0';  // double-null terminator
}

const char* quartz_open_file_dialog(const char* title, const char* filter,
                                    const char* initial_directory, const char* default_ext,
                                    int32_t multiselect, int32_t owner_widget_id) {
    static char buffer[4096];
    static char szFile[4096];
    buffer[0] = '\0';
    szFile[0] = '\0';
    (void)title;

    if (filter && *filter) {
        build_filter_buffer(filter);
    }

    OPENFILENAMEA ofn;
    memset(&ofn, 0, sizeof(ofn));
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = (owner_widget_id >= 0) ? lookup_hwnd(owner_widget_id) : NULL;
    ofn.lpstrFile = szFile;
    ofn.nMaxFile = sizeof(szFile);
    ofn.lpstrFilter = (filter && *filter) ? g_filter_buffer : NULL;
    ofn.nFilterIndex = 1;
    if (initial_directory && *initial_directory) {
        ofn.lpstrInitialDir = initial_directory;
    }
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_EXPLORER;
    if (multiselect) {
        ofn.Flags |= OFN_ALLOWMULTISELECT;
        // Multiselect: ilk dosyayı buffer'a yaz; tam dizi 2. aşamada (show_multi)
        // MVP: ilk seçili dosyayı dönmek yeterli.
    }

    BOOL ok = GetOpenFileNameA(&ofn);
    if (!ok) {
        return NULL;
    }

    // Multiselect: ilk satır dizin, sonraki satırlar dosya adları; ilk dosyayı al
    if (multiselect) {
        // szFile: "C:\\path\\dir\0file1.ext\0file2.ext\0\0"
        const char* first = szFile;
        if (first && *first) {
            // Dizin + ilk dosya birleştir
            const char* file1 = first + strlen(first) + 1;
            if (file1 && *file1) {
                snprintf(buffer, sizeof(buffer), "%s\\%s", first, file1);
            } else {
                snprintf(buffer, sizeof(buffer), "%s", first);
            }
        }
    } else {
        snprintf(buffer, sizeof(buffer), "%s", szFile);
    }

    // Default ext: commdlg otomatik ekler (lpstrDefExt), ek iş gerekmiyor
    (void)default_ext;

    return buffer;
}

const char* quartz_save_file_dialog(const char* title, const char* filter,
                                    const char* initial_directory, const char* default_ext,
                                    const char* file_name, int32_t overwrite_prompt,
                                    int32_t owner_widget_id) {
    static char buffer[4096];
    static char szFile[4096];
    buffer[0] = '\0';
    (void)title;

    if (file_name && *file_name) {
        snprintf(szFile, sizeof(szFile), "%s", file_name);
    } else {
        szFile[0] = '\0';
    }

    if (filter && *filter) {
        build_filter_buffer(filter);
    }

    OPENFILENAMEA ofn;
    memset(&ofn, 0, sizeof(ofn));
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = (owner_widget_id >= 0) ? lookup_hwnd(owner_widget_id) : NULL;
    ofn.lpstrFile = szFile;
    ofn.nMaxFile = sizeof(szFile);
    ofn.lpstrFilter = (filter && *filter) ? g_filter_buffer : NULL;
    ofn.nFilterIndex = 1;
    if (initial_directory && *initial_directory) {
        ofn.lpstrInitialDir = initial_directory;
    }
    if (default_ext && *default_ext) {
        ofn.lpstrDefExt = default_ext;
    }
    ofn.Flags = OFN_EXPLORER;
    if (overwrite_prompt) {
        ofn.Flags |= OFN_OVERWRITEPROMPT;
    }

    BOOL ok = GetSaveFileNameA(&ofn);
    if (!ok) {
        return NULL;
    }

    snprintf(buffer, sizeof(buffer), "%s", szFile);
    return buffer;
}
