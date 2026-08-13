#ifndef QUARTZ_HELPER_H
#define QUARTZ_HELPER_H

#include <stdint.h>

// Platform-neutral C API for the Quartz GUI toolkit.
//
// Implementations:
//   ext/quartz_helper_mac.m   — macOS (AppKit)
//   ext/quartz_helper_gtk.c   — Linux (GTK 3)
//   ext/quartz_helper_qt.cpp  — Linux (Qt 5/6)
//   ext/quartz_helper_win.c   — Windows (Win32 API)

// Callback type: called when a widget event occurs (e.g. button click)
typedef void (*QuartzCallback)(int32_t widget_id);

#ifdef __cplusplus
extern "C" {
#endif

// --- Application lifecycle ---
void quartz_init(void);
void quartz_run(void);
void quartz_terminate(void);

// --- Window ---
int32_t quartz_window_create(const char* title, int32_t width, int32_t height);
void quartz_window_set_title(int32_t widget_id, const char* title);
void quartz_window_show(int32_t widget_id);

// --- Controls ---
int32_t quartz_button_create(const char* title, int32_t x, int32_t y,
                             int32_t width, int32_t height);
int32_t quartz_label_create(const char* text, int32_t x, int32_t y,
                            int32_t width, int32_t height);
int32_t quartz_textbox_create(const char* text, int32_t x, int32_t y,
                              int32_t width, int32_t height);

// --- Widget hierarchy ---
void quartz_widget_set_parent(int32_t child_id, int32_t parent_id);

// --- Widget geometry ---
// Runtime positioning (used by layout managers to reposition children
// after the initial *create call). Coordinates are absolute, in pixels,
// relative to the parent window's content area.
void quartz_widget_set_bounds(int32_t widget_id,
                              int32_t x, int32_t y,
                              int32_t width, int32_t height);

// --- Menus ---
// MenuBar instances are reused for submenus, so a submenu's own id is a
// MenuBar id (enables chained `add_submenu(label) -> MenuBar`).
int32_t quartz_menubar_create(void);
int32_t quartz_contextmenu_create(void);
int32_t quartz_menuitem_create(int32_t parent_id, const char* label);
int32_t quartz_menuseparator_create(void);
void    quartz_menu_add_item(int32_t menu_id, int32_t item_id);
void    quartz_menu_item_set_callback(int32_t item_id, QuartzCallback callback);
void    quartz_window_set_menubar(int32_t window_id, int32_t menubar_id);
void    quartz_widget_set_contextmenu(int32_t widget_id, int32_t menu_id);

// --- Widget properties ---
void quartz_widget_set_text(int32_t widget_id, const char* text);
void quartz_widget_set_callback(int32_t widget_id, QuartzCallback callback);
void quartz_widget_set_enabled(int32_t widget_id, int32_t enabled);

// --- TextBox-specific ---
const char* quartz_textbox_get_text(int32_t widget_id);
void quartz_textbox_set_max_length(int32_t widget_id, int32_t max_length);
void quartz_textbox_set_read_only(int32_t widget_id, int32_t read_only);
void quartz_textbox_set_placeholder(int32_t widget_id, const char* text);
void quartz_textbox_set_password_char(int32_t widget_id, char ch);
void quartz_textbox_set_change_callback(int32_t widget_id, QuartzCallback callback);

// --- ListBox-specific ---
int32_t quartz_listbox_create(int32_t x, int32_t y,
                               int32_t width, int32_t height);
void    quartz_listbox_add_item(int32_t widget_id, const char* text);
void    quartz_listbox_remove_item(int32_t widget_id, int32_t index);
void    quartz_listbox_clear(int32_t widget_id);
int32_t quartz_listbox_get_selected_index(int32_t widget_id);
const char* quartz_listbox_get_selected_text(int32_t widget_id);
void    quartz_listbox_set_selected_index(int32_t widget_id, int32_t index);
int32_t quartz_listbox_get_item_count(int32_t widget_id);
const char* quartz_listbox_get_item_text(int32_t widget_id, int32_t index);
void    quartz_listbox_set_selection_callback(int32_t widget_id, QuartzCallback callback);

// --- ComboBox-specific ---
int32_t quartz_combobox_create(int32_t x, int32_t y, int32_t w, int32_t h, int32_t editable);
void    quartz_combobox_add_item(int32_t wid, const char* text);
void    quartz_combobox_remove_item(int32_t wid, int32_t index);
void    quartz_combobox_clear(int32_t wid);
int32_t quartz_combobox_get_item_count(int32_t wid);
const char* quartz_combobox_get_item_text(int32_t wid, int32_t index);
int32_t quartz_combobox_get_selected_index(int32_t wid);
void    quartz_combobox_set_selected_index(int32_t wid, int32_t index);
const char* quartz_combobox_get_text(int32_t wid);
void    quartz_combobox_set_text(int32_t wid, const char* text);
int32_t quartz_combobox_get_dropped_down(int32_t wid);
void    quartz_combobox_set_dropped_down(int32_t wid, int32_t dropped);
void    quartz_combobox_set_selection_callback(int32_t wid, QuartzCallback cb);
void    quartz_combobox_set_text_callback(int32_t wid, QuartzCallback cb);

// --- File dialogs ---
// Blocking synchronous dialogs. owner_widget_id is the widget whose native
// window owns the dialog, or -1 for no owner.
const char* quartz_open_file_dialog(const char* title,
                                    const char* filter,
                                    const char* initial_directory,
                                    const char* default_ext,
                                    int32_t       multiselect,
                                    int32_t       owner_widget_id);
const char* quartz_save_file_dialog(const char* title,
                                    const char* filter,
                                    const char* initial_directory,
                                    const char* default_ext,
                                    const char* file_name,
                                    int32_t       overwrite_prompt,
                                    int32_t       owner_widget_id);

// --- Toggle (CheckBox / RadioButton) ---
int32_t quartz_checkbox_create(const char* text, int32_t x, int32_t y,
                                int32_t width, int32_t height);
int32_t quartz_radiobutton_create(const char* text, int32_t x, int32_t y,
                                   int32_t width, int32_t height);
int32_t quartz_toggle_get_checked(int32_t widget_id);
void    quartz_toggle_set_checked(int32_t widget_id, int32_t checked);
void    quartz_toggle_set_change_callback(int32_t widget_id, QuartzCallback callback);

#ifdef __cplusplus
}
#endif

#endif // QUARTZ_HELPER_H
