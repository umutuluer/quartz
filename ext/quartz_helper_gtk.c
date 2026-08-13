/*
 * quartz_helper_gtk.c — Linux GTK 3 backend
 *
 * Compile:
 *   gcc -c -fPIC $(pkg-config --cflags gtk+-3.0) ext/quartz_helper_gtk.c \
 *       -o ext/quartz_helper.o
 * Link:
 *   $(pkg-config --libs gtk+-3.0)
 */
#include "quartz_helper.h"
#include <gtk/gtk.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

// ── Widget metadata ────────────────────────────────────────────────────

typedef struct {
    int32_t x;
    int32_t y;
} WidgetPos;

// ── Widget registry ────────────────────────────────────────────────────

// We store GtkWidget* pointers keyed by widget_id.
static GHashTable *widget_map = NULL;

// ── Position registry (x, y per widget) ────────────────────────────────

static GHashTable *position_map = NULL;

// ── Callback registry ──────────────────────────────────────────────────

static GHashTable *callback_map = NULL;

// Change callback registry (for TextBox text changes)
static GHashTable *change_callback_map = NULL;

// Selection callback registry (for ListBox selection changes)
static GHashTable *selection_callback_map = NULL;

// Text change callback registry (for ComboBox entry text changes)
static GHashTable *g_text_callback_map = NULL;

// Toggle change callback registry (for CheckBox / RadioButton checked changes)
static GHashTable *toggle_callback_map = NULL;

// Radio group tracking: parent container → first GSList* radio group
static GHashTable *radio_group_map = NULL;

// ── Widget ID counter ──────────────────────────────────────────────────

static atomic_int next_id = 1;

static int32_t next_widget_id(void) {
    return atomic_fetch_add(&next_id, 1);
}

// ── Helpers ────────────────────────────────────────────────────────────

static void ensure_init(void) {
    if (!widget_map) {
        widget_map   = g_hash_table_new(g_direct_hash, g_direct_equal);
        position_map = g_hash_table_new_full(g_direct_hash, g_direct_equal,
                                             NULL, free);
        callback_map = g_hash_table_new(g_direct_hash, g_direct_equal);
        change_callback_map = g_hash_table_new(g_direct_hash, g_direct_equal);
        selection_callback_map = g_hash_table_new(g_direct_hash, g_direct_equal);
        g_text_callback_map = g_hash_table_new(g_direct_hash, g_direct_equal);
        toggle_callback_map = g_hash_table_new(g_direct_hash, g_direct_equal);
        radio_group_map = g_hash_table_new(g_direct_hash, g_direct_equal);
    }
}

// ── GTK signal handler — bridges to our callback table ─────────────────

static void on_button_clicked(GtkWidget *widget, gpointer user_data) {
    int32_t wid = GPOINTER_TO_INT(user_data);
    QuartzCallback cb = (QuartzCallback)g_hash_table_lookup(callback_map,
                                                            GINT_TO_POINTER(wid));
    if (cb) {
        cb(wid);
    }
}

static void on_toggle_changed(GtkToggleButton *toggle, gpointer user_data) {
    int32_t wid = GPOINTER_TO_INT(user_data);
    QuartzCallback cb = (QuartzCallback)g_hash_table_lookup(toggle_callback_map,
                                                            GINT_TO_POINTER(wid));
    if (cb) {
        cb(wid);
    }
}

static void on_entry_changed(GtkEditable *editable, gpointer user_data) {
    int32_t wid = GPOINTER_TO_INT(user_data);
    QuartzCallback cb = (QuartzCallback)g_hash_table_lookup(change_callback_map,
                                                            GINT_TO_POINTER(wid));
    if (cb) {
        cb(wid);
    }
}

static void on_listbox_selection_changed(GtkTreeSelection *selection, gpointer user_data) {
    int32_t wid = GPOINTER_TO_INT(user_data);
    QuartzCallback cb = (QuartzCallback)g_hash_table_lookup(selection_callback_map,
                                                            GINT_TO_POINTER(wid));
    if (cb) {
        cb(wid);
    }
}

static void on_combobox_selection_changed(GtkComboBox *widget, gpointer user_data) {
    int32_t wid = GPOINTER_TO_INT(user_data);
    QuartzCallback cb = (QuartzCallback)g_hash_table_lookup(selection_callback_map,
                                                            GINT_TO_POINTER(wid));
    if (cb) {
        cb(wid);
    }
}

static void on_combobox_text_changed(GtkEntry *entry, gpointer user_data) {
    int32_t wid = GPOINTER_TO_INT(user_data);
    QuartzCallback cb = (QuartzCallback)g_hash_table_lookup(g_text_callback_map,
                                                            GINT_TO_POINTER(wid));
    if (cb) {
        cb(wid);
    }
}

// =======================================================================
// Public API
// =======================================================================

void quartz_init(void) {
    int argc = 0;
    char **argv = NULL;
    gtk_init(&argc, &argv);
    ensure_init();
}

void quartz_run(void) {
    gtk_main();
}

void quartz_terminate(void) {
    gtk_main_quit();
}

// ── Window ─────────────────────────────────────────────────────────────

int32_t quartz_window_create(const char *title, int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = next_widget_id();

    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), title);
    gtk_window_set_default_size(GTK_WINDOW(window), width, height);

    // Use GtkFixed so (x, y) coordinates are respected
    GtkWidget *fixed = gtk_fixed_new();
    gtk_container_add(GTK_CONTAINER(window), fixed);
    gtk_widget_show(fixed);

    g_hash_table_insert(widget_map, GINT_TO_POINTER(wid), window);

    // Wire up close button → terminate
    g_signal_connect(window, "destroy", G_CALLBACK(quartz_terminate), NULL);

    return wid;
}

void quartz_window_set_title(int32_t widget_id, const char *title) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (widget && GTK_IS_WINDOW(widget)) {
        gtk_window_set_title(GTK_WINDOW(widget), title);
    }
}

void quartz_window_show(int32_t widget_id) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (widget && GTK_IS_WINDOW(widget)) {
        gtk_widget_show_all(widget);
    }
}

// ── Button ─────────────────────────────────────────────────────────────

int32_t quartz_button_create(const char *title, int32_t x, int32_t y,
                              int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = next_widget_id();

    GtkWidget *button = gtk_button_new_with_label(title);
    gtk_widget_set_size_request(button, width, height);

    g_hash_table_insert(widget_map, GINT_TO_POINTER(wid), button);

    // Store position so quartz_widget_set_parent can use it
    WidgetPos *pos = malloc(sizeof(WidgetPos));
    pos->x = x;
    pos->y = y;
    g_hash_table_insert(position_map, GINT_TO_POINTER(wid), pos);

    return wid;
}

// ── Label ──────────────────────────────────────────────────────────────

int32_t quartz_label_create(const char *text, int32_t x, int32_t y,
                             int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = next_widget_id();

    GtkWidget *label = gtk_label_new(text);
    gtk_label_set_xalign(GTK_LABEL(label), 0.0f); // left-align
    gtk_widget_set_size_request(label, width, height);

    g_hash_table_insert(widget_map, GINT_TO_POINTER(wid), label);

    // Store position
    WidgetPos *pos = malloc(sizeof(WidgetPos));
    pos->x = x;
    pos->y = y;
    g_hash_table_insert(position_map, GINT_TO_POINTER(wid), pos);

    return wid;
}

// ── TextBox ────────────────────────────────────────────────────────────

int32_t quartz_textbox_create(const char *text, int32_t x, int32_t y,
                               int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = next_widget_id();

    GtkWidget *entry = gtk_entry_new();
    gtk_entry_set_text(GTK_ENTRY(entry), text);
    gtk_widget_set_size_request(entry, width, height);

    g_hash_table_insert(widget_map, GINT_TO_POINTER(wid), entry);

    // Store position
    WidgetPos *pos = malloc(sizeof(WidgetPos));
    pos->x = x;
    pos->y = y;
    g_hash_table_insert(position_map, GINT_TO_POINTER(wid), pos);

    return wid;
}

const char* quartz_textbox_get_text(int32_t widget_id) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (widget && GTK_IS_ENTRY(widget)) {
        return gtk_entry_get_text(GTK_ENTRY(widget));
    }
    return "";
}

void quartz_textbox_set_max_length(int32_t widget_id, int32_t max_length) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (widget && GTK_IS_ENTRY(widget)) {
        gtk_entry_set_max_length(GTK_ENTRY(widget), max_length);
    }
}

void quartz_textbox_set_read_only(int32_t widget_id, int32_t read_only) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (widget && GTK_IS_ENTRY(widget)) {
        gtk_editable_set_editable(GTK_EDITABLE(widget), read_only ? FALSE : TRUE);
    }
}

void quartz_textbox_set_placeholder(int32_t widget_id, const char* text) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (widget && GTK_IS_ENTRY(widget)) {
        gtk_entry_set_placeholder_text(GTK_ENTRY(widget), text);
    }
}

void quartz_textbox_set_password_char(int32_t widget_id, char ch) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (widget && GTK_IS_ENTRY(widget)) {
        gtk_entry_set_visibility(GTK_ENTRY(widget), FALSE);
        gtk_entry_set_invisible_char(GTK_ENTRY(widget), (gunichar)ch);
    }
}

void quartz_textbox_set_change_callback(int32_t widget_id, QuartzCallback callback) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (callback) {
        g_hash_table_insert(change_callback_map, GINT_TO_POINTER(widget_id),
                            (gpointer)callback);
    } else {
        g_hash_table_remove(change_callback_map, GINT_TO_POINTER(widget_id));
    }

    if (widget && GTK_IS_ENTRY(widget)) {
        g_signal_connect(widget, "changed",
                         G_CALLBACK(on_entry_changed),
                         GINT_TO_POINTER(widget_id));
    }
}

// ── Widget hierarchy ───────────────────────────────────────────────────

void quartz_widget_set_parent(int32_t child_id, int32_t parent_id) {
    GtkWidget *child  = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(child_id));
    GtkWidget *parent = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(parent_id));
    if (!child || !parent) return;

    GtkWidget *container = NULL;

    if (GTK_IS_WINDOW(parent)) {
        // The first child of a GtkWindow is the GtkFixed we created
        GList *children = gtk_container_get_children(GTK_CONTAINER(parent));
        if (children) {
            container = GTK_WIDGET(children->data);
            g_list_free(children);
        }
    } else if (GTK_IS_CONTAINER(parent)) {
        container = parent;
    }

    if (container && GTK_IS_FIXED(container)) {
        WidgetPos *pos = (WidgetPos *)g_hash_table_lookup(position_map,
                                                           GINT_TO_POINTER(child_id));
        gint cx = pos ? pos->x : 0;
        gint cy = pos ? pos->y : 0;
        gtk_fixed_put(GTK_FIXED(container), child, cx, cy);
        gtk_widget_show(child);
    }

    // ── Radio group management ──────────────────────────────────────
    // If the child is a GTK radio button, join the parent's radio group.
    if (GTK_IS_RADIO_BUTTON(child) && container) {
        GSList *group = (GSList *)g_hash_table_lookup(radio_group_map,
                                                       container);
        if (group) {
            gtk_radio_button_join_group(GTK_RADIO_BUTTON(child),
                                        GTK_RADIO_BUTTON(group->data));
        } else {
            // This radio becomes the group leader
            GSList *new_group = gtk_radio_button_get_group(GTK_RADIO_BUTTON(child));
            g_hash_table_insert(radio_group_map, container, new_group);
        }
    }
}

// ── Widget properties ──────────────────────────────────────────────────

void quartz_widget_set_text(int32_t widget_id, const char *text) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (!widget) return;

    if (GTK_IS_BUTTON(widget)) {
        gtk_button_set_label(GTK_BUTTON(widget), text);
    } else if (GTK_IS_LABEL(widget)) {
        gtk_label_set_text(GTK_LABEL(widget), text);
    } else if (GTK_IS_ENTRY(widget)) {
        gtk_entry_set_text(GTK_ENTRY(widget), text);
    }
}

void quartz_widget_set_callback(int32_t widget_id, QuartzCallback callback) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (callback) {
        g_hash_table_insert(callback_map, GINT_TO_POINTER(widget_id),
                            (gpointer)callback);
    } else {
        g_hash_table_remove(callback_map, GINT_TO_POINTER(widget_id));
    }

    if (widget && GTK_IS_BUTTON(widget)) {
        g_signal_connect(widget, "clicked",
                         G_CALLBACK(on_button_clicked),
                         GINT_TO_POINTER(widget_id));
    }
}

void quartz_widget_set_enabled(int32_t widget_id, int32_t enabled) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (widget) {
        gtk_widget_set_sensitive(widget, enabled ? TRUE : FALSE);
    }
}

// ── ListBox ────────────────────────────────────────────────────────────

int32_t quartz_listbox_create(int32_t x, int32_t y,
                               int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = next_widget_id();

    // Create GtkListStore with a single text column
    GtkListStore *store = gtk_list_store_new(1, G_TYPE_STRING);

    // Create GtkTreeView backed by the list store
    GtkWidget *treeView = gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
    // Release our reference on the store (treeView owns it now)
    g_object_unref(store);

    // Add a text renderer column
    GtkCellRenderer *renderer = gtk_cell_renderer_text_new();
    GtkTreeViewColumn *column = gtk_tree_view_column_new_with_attributes(
        "", renderer, "text", 0, NULL);
    gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);
    gtk_tree_view_set_headers_visible(GTK_TREE_VIEW(treeView), FALSE);

    // Wrap in a GtkScrolledWindow for scrollbars
    GtkWidget *scrollWin = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrollWin),
                                   GTK_POLICY_NEVER,
                                   GTK_POLICY_AUTOMATIC);
    gtk_container_add(GTK_CONTAINER(scrollWin), treeView);
    gtk_widget_set_size_request(scrollWin, width, height);

    g_hash_table_insert(widget_map, GINT_TO_POINTER(wid), scrollWin);

    // Store position so quartz_widget_set_parent can use it
    WidgetPos *pos = malloc(sizeof(WidgetPos));
    pos->x = x;
    pos->y = y;
    g_hash_table_insert(position_map, GINT_TO_POINTER(wid), pos);

    return wid;
}

// Helper: get the GtkTreeView and GtkListStore from a ListBox widget_id
static GtkTreeView* get_listbox_treeview(int32_t widget_id) {
    GtkWidget *scrollWin = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                             GINT_TO_POINTER(widget_id));
    if (!scrollWin || !GTK_IS_SCROLLED_WINDOW(scrollWin)) return NULL;

    GList *children = gtk_container_get_children(GTK_CONTAINER(scrollWin));
    if (!children) return NULL;

    GtkWidget *treeView = GTK_WIDGET(children->data);
    g_list_free(children);

    return GTK_IS_TREE_VIEW(treeView) ? GTK_TREE_VIEW(treeView) : NULL;
}

static GtkListStore* get_listbox_store(int32_t widget_id) {
    GtkTreeView *treeView = get_listbox_treeview(widget_id);
    if (!treeView) return NULL;

    GtkTreeModel *model = gtk_tree_view_get_model(treeView);
    return GTK_IS_LIST_STORE(model) ? GTK_LIST_STORE(model) : NULL;
}

void quartz_listbox_add_item(int32_t widget_id, const char* text) {
    GtkListStore *store = get_listbox_store(widget_id);
    if (!store) return;

    GtkTreeIter iter;
    gtk_list_store_append(store, &iter);
    gtk_list_store_set(store, &iter, 0, text, -1);
}

void quartz_listbox_remove_item(int32_t widget_id, int32_t index) {
    GtkListStore *store = get_listbox_store(widget_id);
    if (!store) return;

    GtkTreeIter iter;
    if (gtk_tree_model_iter_nth_child(GTK_TREE_MODEL(store), &iter, NULL, index)) {
        gtk_list_store_remove(store, &iter);
    }
}

void quartz_listbox_clear(int32_t widget_id) {
    GtkListStore *store = get_listbox_store(widget_id);
    if (store) {
        gtk_list_store_clear(store);
    }
}

int32_t quartz_listbox_get_selected_index(int32_t widget_id) {
    GtkTreeView *treeView = get_listbox_treeview(widget_id);
    if (!treeView) return -1;

    GtkTreeSelection *selection = gtk_tree_view_get_selection(treeView);
    GtkTreeIter iter;
    GtkTreeModel *model = NULL;

    if (gtk_tree_selection_get_selected(selection, &model, &iter)) {
        GtkTreePath *path = gtk_tree_model_get_path(model, &iter);
        int32_t index = (int32_t)gtk_tree_path_get_indices(path)[0];
        gtk_tree_path_free(path);
        return index;
    }
    return -1;
}

const char* quartz_listbox_get_selected_text(int32_t widget_id) {
    static char buffer[4096];
    GtkTreeView *treeView = get_listbox_treeview(widget_id);
    if (!treeView) return NULL;

    GtkTreeSelection *selection = gtk_tree_view_get_selection(treeView);
    GtkTreeIter iter;
    GtkTreeModel *model = NULL;

    if (gtk_tree_selection_get_selected(selection, &model, &iter)) {
        gchar *text = NULL;
        gtk_tree_model_get(model, &iter, 0, &text, -1);
        if (text) {
            g_strlcpy(buffer, text, sizeof(buffer));
            g_free(text);
            return buffer;
        }
    }
    return NULL;
}

void quartz_listbox_set_selected_index(int32_t widget_id, int32_t index) {
    GtkTreeView *treeView = get_listbox_treeview(widget_id);
    if (!treeView) return;

    GtkTreeSelection *selection = gtk_tree_view_get_selection(treeView);

    if (index < 0) {
        gtk_tree_selection_unselect_all(selection);
        return;
    }

    GtkTreePath *path = gtk_tree_path_new_from_indices(index, -1);
    if (path) {
        gtk_tree_selection_select_path(selection, path);
        gtk_tree_path_free(path);
    }
}

int32_t quartz_listbox_get_item_count(int32_t widget_id) {
    GtkListStore *store = get_listbox_store(widget_id);
    return store ? gtk_tree_model_iter_n_children(GTK_TREE_MODEL(store), NULL) : 0;
}

const char* quartz_listbox_get_item_text(int32_t widget_id, int32_t index) {
    static char buffer[4096];
    GtkListStore *store = get_listbox_store(widget_id);
    if (!store) return "";

    GtkTreeIter iter;
    if (gtk_tree_model_iter_nth_child(GTK_TREE_MODEL(store), &iter, NULL, index)) {
        gchar *text = NULL;
        gtk_tree_model_get(GTK_TREE_MODEL(store), &iter, 0, &text, -1);
        if (text) {
            g_strlcpy(buffer, text, sizeof(buffer));
            g_free(text);
            return buffer;
        }
    }
    return "";
}

void quartz_listbox_set_selection_callback(int32_t widget_id, QuartzCallback callback) {
    GtkTreeView *treeView = get_listbox_treeview(widget_id);

    if (callback) {
        g_hash_table_insert(selection_callback_map, GINT_TO_POINTER(widget_id),
                            (gpointer)callback);
    } else {
        g_hash_table_remove(selection_callback_map, GINT_TO_POINTER(widget_id));
    }

    if (treeView) {
        GtkTreeSelection *selection = gtk_tree_view_get_selection(treeView);
        g_signal_connect(selection, "changed",
                         G_CALLBACK(on_listbox_selection_changed),
                         GINT_TO_POINTER(widget_id));
    }
}

// ── ComboBox ───────────────────────────────────────────────────────────

int32_t quartz_combobox_create(int32_t x, int32_t y, int32_t w, int32_t h,
                                int32_t editable) {
    ensure_init();
    int32_t wid = next_widget_id();

    GtkWidget *combo = editable
        ? gtk_combo_box_text_new_with_entry()
        : gtk_combo_box_text_new();
    gtk_widget_set_size_request(combo, w, h);

    g_hash_table_insert(widget_map, GINT_TO_POINTER(wid), combo);

    // Store position so quartz_widget_set_parent can use it
    WidgetPos *pos = malloc(sizeof(WidgetPos));
    pos->x = x;
    pos->y = y;
    g_hash_table_insert(position_map, GINT_TO_POINTER(wid), pos);

    // Remember whether the entry is editable (used by get/set_text)
    g_object_set_data(G_OBJECT(combo), "editable", GINT_TO_POINTER(editable));

    // Wire up "changed" → selection callback (fires on active item changes)
    g_signal_connect(combo, "changed",
                     G_CALLBACK(on_combobox_selection_changed),
                     GINT_TO_POINTER(wid));

    // For editable combo boxes, also forward entry text changes
    if (editable) {
        GtkWidget *entry = gtk_bin_get_child(GTK_BIN(combo));
        g_signal_connect(entry, "changed",
                         G_CALLBACK(on_combobox_text_changed),
                         GINT_TO_POINTER(wid));
    }

    return wid;
}

// Helper: get the GtkComboBox widget from a ComboBox widget_id
static GtkWidget* get_combobox_widget(int32_t widget_id) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (widget && GTK_IS_COMBO_BOX(widget)) return widget;
    return NULL;
}

void quartz_combobox_add_item(int32_t widget_id, const char* text) {
    GtkWidget *combo = get_combobox_widget(widget_id);
    if (!combo || !GTK_IS_COMBO_BOX_TEXT(combo)) return;

    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(combo), text);
}

void quartz_combobox_remove_item(int32_t widget_id, int32_t index) {
    GtkWidget *combo = get_combobox_widget(widget_id);
    if (!combo || !GTK_IS_COMBO_BOX_TEXT(combo)) return;

    gtk_combo_box_text_remove(GTK_COMBO_BOX_TEXT(combo), index);
}

void quartz_combobox_clear(int32_t widget_id) {
    GtkWidget *combo = get_combobox_widget(widget_id);
    if (combo && GTK_IS_COMBO_BOX_TEXT(combo)) {
        gtk_combo_box_text_remove_all(GTK_COMBO_BOX_TEXT(combo));
    }
}

int32_t quartz_combobox_get_item_count(int32_t widget_id) {
    GtkWidget *combo = get_combobox_widget(widget_id);
    if (!combo) return 0;

    GtkTreeModel *model = gtk_combo_box_get_model(GTK_COMBO_BOX(combo));
    return model ? gtk_tree_model_iter_n_children(model, NULL) : 0;
}

const char* quartz_combobox_get_item_text(int32_t widget_id, int32_t index) {
    static char buffer[4096];
    GtkWidget *combo = get_combobox_widget(widget_id);
    if (!combo) return "";

    GtkTreeModel *model = gtk_combo_box_get_model(GTK_COMBO_BOX(combo));
    GtkTreeIter iter;
    if (gtk_tree_model_iter_nth_child(model, &iter, NULL, index)) {
        gchar *text = NULL;
        gtk_tree_model_get(model, &iter, 0, &text, -1);
        if (text) {
            g_strlcpy(buffer, text, sizeof(buffer));
            g_free(text);
            return buffer;
        }
    }
    return "";
}

int32_t quartz_combobox_get_selected_index(int32_t widget_id) {
    GtkWidget *combo = get_combobox_widget(widget_id);
    if (!combo) return -1;

    return (int32_t)gtk_combo_box_get_active(GTK_COMBO_BOX(combo));
}

void quartz_combobox_set_selected_index(int32_t widget_id, int32_t index) {
    GtkWidget *combo = get_combobox_widget(widget_id);
    if (combo) {
        gtk_combo_box_set_active(GTK_COMBO_BOX(combo), index);
    }
}

const char* quartz_combobox_get_text(int32_t widget_id) {
    static char buffer[4096];
    GtkWidget *combo = get_combobox_widget(widget_id);
    if (!combo) return "";

    if (GPOINTER_TO_INT(g_object_get_data(G_OBJECT(combo), "editable"))) {
        GtkWidget *entry = gtk_bin_get_child(GTK_BIN(combo));
        if (entry && GTK_IS_ENTRY(entry)) {
            const gchar *text = gtk_entry_get_text(GTK_ENTRY(entry));
            if (text) {
                g_strlcpy(buffer, text, sizeof(buffer));
                return buffer;
            }
        }
    } else {
        gchar *text = gtk_combo_box_text_get_active_text(GTK_COMBO_BOX_TEXT(combo));
        if (text) {
            g_strlcpy(buffer, text, sizeof(buffer));
            g_free(text);
            return buffer;
        }
    }
    return "";
}

void quartz_combobox_set_text(int32_t widget_id, const char* text) {
    GtkWidget *combo = get_combobox_widget(widget_id);
    if (!combo) return;

    // Setting free text only makes sense for editable combo boxes; on
    // read-only ones this would fight with the active selection.
    if (!GPOINTER_TO_INT(g_object_get_data(G_OBJECT(combo), "editable"))) return;

    GtkWidget *entry = gtk_bin_get_child(GTK_BIN(combo));
    if (entry && GTK_IS_ENTRY(entry)) {
        gtk_entry_set_text(GTK_ENTRY(entry), text);
    }
}

int32_t quartz_combobox_get_dropped_down(int32_t widget_id) {
    // GTK 3 has no public API to query whether the popup is currently shown,
    // so we report 0 (not dropped down) unconditionally for this backend.
    (void)widget_id;
    return 0;
}

void quartz_combobox_set_dropped_down(int32_t widget_id, int32_t dropped) {
    GtkWidget *combo = get_combobox_widget(widget_id);
    if (!combo) return;

    if (dropped) {
        gtk_combo_box_popup(GTK_COMBO_BOX(combo));
    } else {
        gtk_combo_box_popdown(GTK_COMBO_BOX(combo));
    }
}

void quartz_combobox_set_selection_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        g_hash_table_insert(selection_callback_map, GINT_TO_POINTER(widget_id),
                            (gpointer)callback);
    } else {
        g_hash_table_remove(selection_callback_map, GINT_TO_POINTER(widget_id));
    }
}

void quartz_combobox_set_text_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        g_hash_table_insert(g_text_callback_map, GINT_TO_POINTER(widget_id),
                            (gpointer)callback);
    } else {
        g_hash_table_remove(g_text_callback_map, GINT_TO_POINTER(widget_id));
    }
}

// ── CheckBox ────────────────────────────────────────────────────────────

int32_t quartz_checkbox_create(const char *text, int32_t x, int32_t y,
                                int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = next_widget_id();

    GtkWidget *check = gtk_check_button_new_with_label(text);
    gtk_widget_set_size_request(check, width, height);

    g_hash_table_insert(widget_map, GINT_TO_POINTER(wid), check);

    // Store position
    WidgetPos *pos = malloc(sizeof(WidgetPos));
    pos->x = x;
    pos->y = y;
    g_hash_table_insert(position_map, GINT_TO_POINTER(wid), pos);

    return wid;
}

// ── RadioButton ─────────────────────────────────────────────────────────

int32_t quartz_radiobutton_create(const char *text, int32_t x, int32_t y,
                                   int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = next_widget_id();

    // Create radio button without a group — group is assigned in set_parent
    GtkWidget *radio = gtk_radio_button_new_with_label(NULL, text);
    gtk_widget_set_size_request(radio, width, height);

    g_hash_table_insert(widget_map, GINT_TO_POINTER(wid), radio);

    // Store position
    WidgetPos *pos = malloc(sizeof(WidgetPos));
    pos->x = x;
    pos->y = y;
    g_hash_table_insert(position_map, GINT_TO_POINTER(wid), pos);

    return wid;
}

// ── Toggle state (shared by CheckBox and RadioButton) ───────────────────

int32_t quartz_toggle_get_checked(int32_t widget_id) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (widget && GTK_IS_TOGGLE_BUTTON(widget)) {
        return gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(widget)) ? 1 : 0;
    }
    return 0;
}

void quartz_toggle_set_checked(int32_t widget_id, int32_t checked) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (!widget || !GTK_IS_TOGGLE_BUTTON(widget)) return;

    gboolean new_state = checked ? TRUE : FALSE;
    if (gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(widget)) != new_state) {
        gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(widget), new_state);
        // gtk_toggle_button_set_active fires "toggled" automatically,
        // which dispatches through on_toggle_changed → callback
    }
}

void quartz_toggle_set_change_callback(int32_t widget_id, QuartzCallback callback) {
    GtkWidget *widget = (GtkWidget *)g_hash_table_lookup(widget_map,
                                                          GINT_TO_POINTER(widget_id));
    if (callback) {
        g_hash_table_insert(toggle_callback_map, GINT_TO_POINTER(widget_id),
                            (gpointer)callback);
    } else {
        g_hash_table_remove(toggle_callback_map, GINT_TO_POINTER(widget_id));
    }

    if (widget && GTK_IS_TOGGLE_BUTTON(widget)) {
        g_signal_connect(widget, "toggled",
                         G_CALLBACK(on_toggle_changed),
                         GINT_TO_POINTER(widget_id));
    }
}

// ── File dialogs ────────────────────────────────────────────────────────

// Parse a WinForms-style filter string ("Display (*.ext)|*.ext|...") into a
// GList of GtkFileFilter*. Each display+pattern pair becomes one filter.
static GList* build_filters_from_string(const char* filter_str) {
    GList *list = NULL;
    if (!filter_str || !*filter_str) return NULL;
    char *copy = g_strdup(filter_str);
    char *saveptr1 = NULL;
    char *token = strtok_r(copy, "|", &saveptr1);
    char *current_display = NULL;
    while (token) {
        if (!current_display) {
            current_display = token;
        } else {
            GtkFileFilter *gf = gtk_file_filter_new();
            gtk_file_filter_set_name(gf, current_display);
            gtk_file_filter_add_pattern(gf, token);
            list = g_list_append(list, gf);
            current_display = NULL;
        }
        token = strtok_r(NULL, "|", &saveptr1);
    }
    g_free(copy);
    return list;
}

// Resolve a widget_id to the GtkWindow that owns it (itself if a window,
// otherwise its toplevel). Returns NULL for -1 or unknown ids.
static GtkWindow* find_owner_window(int32_t owner_widget_id) {
    if (owner_widget_id < 0) return NULL;
    GtkWidget *w = (GtkWidget*)g_hash_table_lookup(widget_map,
                                                   GINT_TO_POINTER(owner_widget_id));
    if (!w) return NULL;
    if (GTK_IS_WINDOW(w)) return GTK_WINDOW(w);
    if (GTK_IS_WIDGET(w)) {
        GtkWidget *toplevel = gtk_widget_get_toplevel(w);
        if (toplevel && GTK_IS_WINDOW(toplevel)) return GTK_WINDOW(toplevel);
    }
    return NULL;
}

const char* quartz_open_file_dialog(const char* title, const char* filter_str,
                                    const char* initial_directory, const char* default_ext,
                                    int32_t multiselect, int32_t owner_widget_id) {
    static char buffer[4096];
    buffer[0] = '\0';

    GtkWindow *owner = find_owner_window(owner_widget_id);

    const char *btn_open = multiselect ? "Select" : "Open";
    GtkWidget *dialog = gtk_file_chooser_dialog_new(
        title && *title ? title : "Open File",
        owner,
        GTK_FILE_CHOOSER_ACTION_OPEN,
        "_Cancel", GTK_RESPONSE_CANCEL,
        btn_open, GTK_RESPONSE_ACCEPT,
        NULL
    );

    if (initial_directory && *initial_directory) {
        gtk_file_chooser_set_current_folder(GTK_FILE_CHOOSER(dialog), initial_directory);
    }

    GList *filters = build_filters_from_string(filter_str);
    for (GList *l = filters; l != NULL; l = l->next) {
        gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), GTK_FILE_FILTER(l->data));
    }
    if (filters) {
        gtk_file_chooser_set_filter(GTK_FILE_CHOOSER(dialog), GTK_FILE_FILTER(filters->data));
    }

    if (multiselect) {
        gtk_file_chooser_set_select_multiple(GTK_FILE_CHOOSER(dialog), TRUE);
    }

    (void)default_ext;  // GTK file filter pattern'lerinden gelir

    gint resp = gtk_dialog_run(GTK_DIALOG(dialog));

    const char *result = NULL;
    if (resp == GTK_RESPONSE_ACCEPT) {
        if (multiselect) {
            GSList *files = gtk_file_chooser_get_filenames(GTK_FILE_CHOOSER(dialog));
            if (files) {
                // MVP: ilk dosya
                snprintf(buffer, sizeof(buffer), "%s", (const char*)files->data);
                g_slist_free_full(files, g_free);
            }
        } else {
            char *file = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
            if (file) {
                snprintf(buffer, sizeof(buffer), "%s", file);
                g_free(file);
            }
        }
        result = buffer;
    }

    g_list_free_full(filters, g_object_unref);
    gtk_widget_destroy(dialog);

    return result;  // NULL = cancel
}

const char* quartz_save_file_dialog(const char* title, const char* filter_str,
                                    const char* initial_directory, const char* default_ext,
                                    const char* file_name, int32_t overwrite_prompt,
                                    int32_t owner_widget_id) {
    static char buffer[4096];
    buffer[0] = '\0';

    GtkWindow *owner = find_owner_window(owner_widget_id);

    GtkWidget *dialog = gtk_file_chooser_dialog_new(
        title && *title ? title : "Save File",
        owner,
        GTK_FILE_CHOOSER_ACTION_SAVE,
        "_Cancel", GTK_RESPONSE_CANCEL,
        "_Save", GTK_RESPONSE_ACCEPT,
        NULL
    );

    if (initial_directory && *initial_directory) {
        gtk_file_chooser_set_current_folder(GTK_FILE_CHOOSER(dialog), initial_directory);
    }
    if (file_name && *file_name) {
        gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(dialog), file_name);
    }
    if (default_ext && *default_ext) {
        gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(dialog), (overwrite_prompt != 0));
    }
    // Default ext: GTK'da gtk_file_chooser_set_current_folder + filter'dan gelir, explicit extension
    // ayarlamak için ayrı API yoktur; filter pattern'ine güveniyoruz
    (void)default_ext;

    GList *filters = build_filters_from_string(filter_str);
    for (GList *l = filters; l != NULL; l = l->next) {
        gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), GTK_FILE_FILTER(l->data));
    }
    if (filters) {
        gtk_file_chooser_set_filter(GTK_FILE_CHOOSER(dialog), GTK_FILE_FILTER(filters->data));
    }

    gint resp = gtk_dialog_run(GTK_DIALOG(dialog));

    const char *result = NULL;
    if (resp == GTK_RESPONSE_ACCEPT) {
        char *file = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        if (file) {
            snprintf(buffer, sizeof(buffer), "%s", file);
            g_free(file);
        }
        result = buffer;
    }

    g_list_free_full(filters, g_object_unref);
    gtk_widget_destroy(dialog);

    return result;
}
