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

static void on_entry_changed(GtkEditable *editable, gpointer user_data) {
    int32_t wid = GPOINTER_TO_INT(user_data);
    QuartzCallback cb = (QuartzCallback)g_hash_table_lookup(change_callback_map,
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
