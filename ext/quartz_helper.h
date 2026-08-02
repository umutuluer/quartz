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

#ifdef __cplusplus
}
#endif

#endif // QUARTZ_HELPER_H
