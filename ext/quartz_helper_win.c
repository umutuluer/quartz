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

// ── Dialog test seam ─────────────────────────────────────────
// When enabled, the open/save dialog functions return a canned path
// instead of running a blocking modal. QUARTZ_TEST_DIALOG_PATH is read at
// call time (empty => cancel), falling back to the hardcoded defaults.
static int quartz_test_dialog_mode = 0;

static int dialog_test_active(void) {
    return quartz_test_dialog_mode != 0 || getenv("QUARTZ_TEST_DIALOG") != NULL;
}

static const char* dialog_test_path(const char *fallback) {
    const char *p = getenv("QUARTZ_TEST_DIALOG_PATH");
    if (p && p[0] == '\0') return NULL;  // empty => cancel
    return p ? p : fallback;
}

void quartz_test_dialog_set_mode(int on) {
    quartz_test_dialog_mode = on ? 1 : 0;
}

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

// ── Menu registries ────────────────────────────────────────────────────
// Menu callbacks, menu handles, menu items, and context-menu bindings use
// the same widget_id → entry linked-list pattern as the widget registries
// above.

// Menu callback registry: widget_id → QuartzCallback (for MenuItem activation)
static CallbackEntry *g_menu_callback_head = NULL;

static CallbackEntry* find_menu_callback(int32_t widget_id) {
    CallbackEntry *e = g_menu_callback_head;
    while (e) {
        if (e->widget_id == widget_id) return e;
        e = e->next;
    }
    return NULL;
}

static void set_menu_callback(int32_t widget_id, QuartzCallback callback) {
    CallbackEntry *e = find_menu_callback(widget_id);
    if (e) {
        e->callback = callback;
    } else if (callback) {
        e = (CallbackEntry*)malloc(sizeof(CallbackEntry));
        e->widget_id = widget_id;
        e->callback  = callback;
        e->next      = g_menu_callback_head;
        g_menu_callback_head = e;
    }
}

// Menu registry: widget_id → HMENU (menubar and popup roots)
typedef struct MenuEntry {
    int32_t widget_id;
    HMENU   hmenu;
    struct MenuEntry *next;
} MenuEntry;

static MenuEntry *g_menu_map = NULL;

static void register_menu(int32_t widget_id, HMENU hmenu) {
    MenuEntry *e = (MenuEntry*)malloc(sizeof(MenuEntry));
    e->widget_id = widget_id;
    e->hmenu     = hmenu;
    e->next      = g_menu_map;
    g_menu_map   = e;
}

static HMENU find_menu(int32_t widget_id) {
    MenuEntry *e = g_menu_map;
    while (e) {
        if (e->widget_id == widget_id) return e->hmenu;
        e = e->next;
    }
    return NULL;
}

// Menu item registry: widget_id ↔ Win32 menu item ID.
//
// Win32 menu items are addressed by an item ID (the LOWORD of WM_COMMAND),
// not by a string. Each MenuItem therefore gets a unique item ID from a
// dedicated counter that starts at 100 so it can never collide with control
// IDs (widget_ids come from g_next_id). The caption string is stored here so
// quartz_menu_add_item can hand it to AppendMenuA.
static LONG g_next_menu_item_id = 100;

typedef struct MenuItemEntry {
    int32_t widget_id;
    UINT    item_id;
    char*   caption;   // owned by this entry; NULL for separators
    struct MenuItemEntry *next;
} MenuItemEntry;

static MenuItemEntry *g_menu_item_map = NULL;

static MenuItemEntry* find_menu_item(int32_t widget_id) {
    MenuItemEntry *e = g_menu_item_map;
    while (e) {
        if (e->widget_id == widget_id) return e;
        e = e->next;
    }
    return NULL;
}

static MenuItemEntry* find_menu_item_by_id(UINT item_id) {
    MenuItemEntry *e = g_menu_item_map;
    while (e) {
        if (e->item_id == item_id) return e;
        e = e->next;
    }
    return NULL;
}

// Context-menu bindings: widget_id → menu_id
typedef struct ContextMenuEntry {
    int32_t widget_id;
    int32_t menu_id;
    struct ContextMenuEntry *next;
} ContextMenuEntry;

static ContextMenuEntry *g_context_menu_head = NULL;

static void register_context_menu(int32_t widget_id, int32_t menu_id) {
    // Replace an existing binding for the same widget, else prepend.
    ContextMenuEntry *e = g_context_menu_head;
    while (e) {
        if (e->widget_id == widget_id) {
            e->menu_id = menu_id;
            return;
        }
        e = e->next;
    }
    e = (ContextMenuEntry*)malloc(sizeof(ContextMenuEntry));
    e->widget_id = widget_id;
    e->menu_id   = menu_id;
    e->next      = g_context_menu_head;
    g_context_menu_head = e;
}

static int32_t lookup_context_menu(int32_t widget_id) {
    ContextMenuEntry *e = g_context_menu_head;
    while (e) {
        if (e->widget_id == widget_id) return e->menu_id;
        e = e->next;
    }
    return -1;
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
        // Menu / accelerator commands first. For these HIWORD(wParam) is 0
        // (menu) or 1 (accelerator) and LOWORD(wParam) is the menu item ID.
        // Route them through the menu item map before the control path so a
        // menu item ID can never be mistaken for a control ID.
        WORD notify = HIWORD(wParam);
        if (notify == 0 || notify == 1) {
            UINT item_id = LOWORD(wParam);
            MenuItemEntry *me = find_menu_item_by_id(item_id);
            if (me) {
                // find_menu_callback follows the same registry pattern as the
                // widget callbacks: it returns the linked-list entry, so read
                // the callback out of it.
                CallbackEntry *ce = find_menu_callback(me->widget_id);
                if (ce && ce->callback) {
                    ce->callback(me->widget_id);
                }
                return 0;
            }
        }

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

    case WM_CONTEXTMENU: {
        // Right-click (or Shift+F10 / context-menu key) on a child widget:
        // resolve the widget_id, show its bound context menu, and re-dispatch
        // the chosen item through WM_COMMAND so menu callbacks stay in one
        // place. wParam is NULL for keyboard invocation, so fall back to the
        // top-level window in that case.
        HWND child_hwnd = (HWND)wParam;
        if (child_hwnd == NULL) child_hwnd = hwnd;

        int32_t widget_id = (int32_t)(uintptr_t)GetPropA(child_hwnd, PROP_WIDGET_ID);
        if (widget_id == 0) {
            widget_id = (int32_t)GetWindowLongPtrA(child_hwnd, GWLP_ID);
        }

        int32_t menu_id = lookup_context_menu(widget_id);
        HMENU hmenu = (menu_id >= 0) ? find_menu(menu_id) : NULL;
        if (!hmenu) return 0;

        POINT pt;
        GetCursorPos(&pt);
        int cmd = (int)TrackPopupMenu(hmenu,
                                      TPM_RIGHTBUTTON | TPM_RETURNCMD,
                                      pt.x, pt.y, 0, hwnd, NULL);
        if (cmd > 0) {
            // Re-dispatch via our own wnd_proc (hwnd) — sending to a child
            // control would deliver the message to the control's class proc
            // instead of the menu routing in quartz_wnd_proc.
            SendMessageA(hwnd, WM_COMMAND, MAKEWPARAM(cmd, 0), 0);
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

// Runtime positioning (used by layout managers to reposition children
// after the initial *create call). Coordinates are absolute, in pixels,
// relative to the parent window's content area.
void quartz_widget_set_bounds(int32_t widget_id, int32_t x, int32_t y,
                              int32_t width, int32_t height) {
    HWND hwnd = find_hwnd(widget_id);
    if (!hwnd) return;

    // MoveWindow ignores x/y for top-level windows (uses screen coords);
    // for child windows (WS_CHILD) it's relative to parent client area.
    MoveWindow(hwnd, x, y, width, height, TRUE);
}

void quartz_widget_get_bounds(int32_t widget_id, int32_t *out_x, int32_t *out_y,
                              int32_t *out_w, int32_t *out_h) {
    if (out_x) *out_x = 0;
    if (out_y) *out_y = 0;
    if (out_w) *out_w = 0;
    if (out_h) *out_h = 0;

    HWND hwnd = find_hwnd(widget_id);
    if (!hwnd) return;
    RECT rc;
    if (GetWindowRect(hwnd, &rc)) {
        if (out_x) *out_x = rc.left;
        if (out_y) *out_y = rc.top;
        if (out_w) *out_w = rc.right - rc.left;
        if (out_h) *out_h = rc.bottom - rc.top;
    }
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

    if (dialog_test_active()) {
        const char *mock = dialog_test_path("/tmp/quartz_test_open.txt");
        if (!mock) return NULL;  // empty QUARTZ_TEST_DIALOG_PATH => cancel
        snprintf(buffer, sizeof(buffer), "%s", mock);
        return buffer;
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

    if (dialog_test_active()) {
        const char *mock = dialog_test_path("/tmp/quartz_test_save.txt");
        if (!mock) return NULL;  // empty QUARTZ_TEST_DIALOG_PATH => cancel
        snprintf(buffer, sizeof(buffer), "%s", mock);
        if (default_ext && *default_ext) {
            char suffix[64];
            snprintf(suffix, sizeof(suffix), ".%s", default_ext);
            size_t blen = strlen(buffer);
            size_t slen = strlen(suffix);
            if (blen < slen || strcmp(buffer + blen - slen, suffix) != 0) {
                snprintf(buffer + blen, sizeof(buffer) - blen, "%s", suffix);
            }
        }
        return buffer;
    }

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

// ── Menus ──────────────────────────────────────────────────────────────
// Wave 1b — full Win32 implementation. Win32 already links user32.dll
// (CreateMenu/CreatePopupMenu/SetMenu/AppendMenuA/TrackPopupMenu), so no
// additional link flags are needed.

int32_t quartz_menubar_create(void) {
    HMENU hmenu = CreateMenu();
    if (!hmenu) return 0;

    int32_t wid = InterlockedIncrement(&g_next_id);
    register_menu(wid, hmenu);

    return wid;
}

int32_t quartz_contextmenu_create(void) {
    HMENU hmenu = CreatePopupMenu();
    if (!hmenu) return 0;

    int32_t wid = InterlockedIncrement(&g_next_id);
    register_menu(wid, hmenu);

    return wid;
}

int32_t quartz_menuitem_create(int32_t parent_id, const char* label) {
    (void)parent_id;  // MVP: chained add_item; auto-append is not done here

    int32_t wid  = InterlockedIncrement(&g_next_id);
    UINT item_id = (UINT)InterlockedIncrement(&g_next_menu_item_id);

    // The caption is owned by this entry so quartz_menu_add_item can pass it
    // to AppendMenuA together with the item ID.
    MenuItemEntry *e = (MenuItemEntry*)malloc(sizeof(MenuItemEntry));
    e->widget_id = wid;
    e->item_id   = item_id;
    e->caption   = label ? _strdup(label) : _strdup("");
    e->next      = g_menu_item_map;
    g_menu_item_map = e;

    return wid;
}

int32_t quartz_menuseparator_create(void) {
    int32_t wid  = InterlockedIncrement(&g_next_id);
    UINT item_id = (UINT)InterlockedIncrement(&g_next_menu_item_id);

    MenuItemEntry *e = (MenuItemEntry*)malloc(sizeof(MenuItemEntry));
    e->widget_id = wid;
    e->item_id   = item_id;
    e->caption   = NULL;  // separator
    e->next      = g_menu_item_map;
    g_menu_item_map = e;

    return wid;
}

void quartz_menu_add_item(int32_t menu_id, int32_t item_id) {
    HMENU hmenu = find_menu(menu_id);
    if (!hmenu) return;

    MenuItemEntry *e = find_menu_item(item_id);
    if (!e) return;

    if (e->caption == NULL) {
        AppendMenuA(hmenu, MF_SEPARATOR, e->item_id, NULL);
    } else {
        AppendMenuA(hmenu, MF_STRING, e->item_id, e->caption);
    }
}

void quartz_menu_item_set_callback(int32_t item_id, QuartzCallback callback) {
    if (callback) {
        set_menu_callback(item_id, callback);
    }
}

void quartz_window_set_menubar(int32_t window_id, int32_t menubar_id) {
    HWND hwnd = find_hwnd(window_id);
    HMENU hmenu = find_menu(menubar_id);
    if (!hwnd || !hmenu) return;

    SetMenu(hwnd, hmenu);
    DrawMenuBar(hwnd);  // required — without it the menubar is never drawn
}

void quartz_widget_set_contextmenu(int32_t widget_id, int32_t menu_id) {
    // Only the binding is recorded here; the actual popup dispatch happens in
    // the WM_CONTEXTMENU handler of quartz_wnd_proc.
    register_context_menu(widget_id, menu_id);
}

// =======================================================================
// Test trampolines
//
// These walk the same per-type linked lists (CallbackEntry chains) that the
// WM_COMMAND handler dispatches through. Each find_* helper returns the
// matching node by widget_id, or NULL — which makes unknown ids and widgets
// with no registered callback natural no-ops.
// =======================================================================

void quartz_test_fire_button_click(int32_t widget_id) {
    CallbackEntry *e = find_callback(widget_id);
    if (e && e->callback) e->callback(widget_id);
}

void quartz_test_fire_toggle_checked(int32_t widget_id) {
    // CheckBox + RadioButton share the toggle list (checked first in WM_COMMAND)
    CallbackEntry *e = find_toggle_callback(widget_id);
    if (e && e->callback) e->callback(widget_id);
}

void quartz_test_fire_text_change(int32_t widget_id) {
    CallbackEntry *e = find_change_callback(widget_id);
    if (e && e->callback) e->callback(widget_id);
}

void quartz_test_fire_listbox_selection(int32_t widget_id) {
    CallbackEntry *e = find_selection_callback(widget_id);
    if (e && e->callback) e->callback(widget_id);
}

void quartz_test_fire_combobox_selection(int32_t widget_id) {
    CallbackEntry *e = find_selection_callback(widget_id);
    if (e && e->callback) e->callback(widget_id);
}

void quartz_test_fire_combobox_text(int32_t widget_id) {
    CallbackEntry *e = find_text_callback(widget_id);
    if (e && e->callback) e->callback(widget_id);
}

void quartz_test_fire_menu_item(int32_t widget_id) {
    CallbackEntry *e = find_menu_callback(widget_id);
    if (e && e->callback) e->callback(widget_id);
}
