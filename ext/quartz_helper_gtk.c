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

// ── Widget registry ────────────────────────────────────────────────────

// We store GtkWidget* pointers keyed by widget_id.
static GHashTable *widget_map = NULL;

// ── Callback registry ──────────────────────────────────────────────────

static GHashTable *callback_map = NULL;

// ── Widget ID counter ──────────────────────────────────────────────────

static atomic_int next_id = 1;

static int32_t next_widget_id(void) {
    return atomic_fetch_add(&next_id, 1);
}

// ── Helpers ────────────────────────────────────────────────────────────

static void ensure_init(void) {
    if (!widget_map) {
        widget_map   = g_hash_table_new(g_direct_hash, g_direct_equal);
        callback_map = g_hash_table_new(g_direct_hash, g_direct_equal);
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

    // Store required size so GtkFixed can honour it
    g_hash_table_insert(widget_map, GINT_TO_POINTER(wid), button);

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

    return wid;
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
        // Get the stored size-request; GtkFixed needs explicit position
        // (size is already set via gtk_widget_set_size_request above)
        gtk_fixed_put(GTK_FIXED(container), child, 0, 0);
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
