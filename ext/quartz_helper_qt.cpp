/*
 * quartz_helper_qt.cpp — Linux Qt 5 / Qt 6 backend
 *
 * Compile (Qt 5):
 *   g++ -c -fPIC $(pkg-config --cflags Qt5Widgets) ext/quartz_helper_qt.cpp \
 *       -o ext/quartz_helper.o
 *
 * Compile (Qt 6):
 *   g++ -c -fPIC $(pkg-config --cflags Qt6Widgets) ext/quartz_helper_qt.cpp \
 *       -o ext/quartz_helper.o
 *
 * Link:
 *   $(pkg-config --libs Qt5Widgets)   # or Qt6Widgets
 */
#include "quartz_helper.h"

#include <QApplication>
#include <QWidget>
#include <QPushButton>
#include <QLabel>
#include <QMap>
#include <QAtomicInt>

// ═══════════════════════════════════════════════════════════════════════
// Internal helpers — the header function that wraps Qt setup
// ═══════════════════════════════════════════════════════════════════════

namespace {

// We need a static QApplication* that lives for the whole program.
// quartz_init creates it; quartz_run starts its event loop.
static QApplication *g_app = nullptr;

// Widget registry: widget_id → QWidget*
static QMap<int32_t, QWidget*> *g_widgets = nullptr;

// Callback registry: widget_id → QuartzCallback
static QMap<int32_t, QuartzCallback> *g_callbacks = nullptr;

// Thread-safe ID counter
static QAtomicInt g_next_id(1);

void ensure_init() {
    if (!g_widgets) {
        g_widgets   = new QMap<int32_t, QWidget*>();
        g_callbacks = new QMap<int32_t, QuartzCallback>();
    }
}

// Helper: get the QWidget content container from a window
// QWidget itself is the window AND the container.
// Children are added directly to the window widget.
QWidget* container_of(QWidget *widget) {
    return widget; // Qt: windows ARE containers
}

} // anonymous namespace

// ═══════════════════════════════════════════════════════════════════════
// Public C API — extern "C" so the linker sees C symbols
// ═══════════════════════════════════════════════════════════════════════

extern "C" {

void quartz_init(void) {
    // QApplication requires argc/argv. We pass dummy values since the
    // host Crystal app won't forward command-line arguments.
    static int dummy_argc = 1;
    static char  dummy_argv0[] = "quartz_app";
    static char *dummy_argv[] = {dummy_argv0, nullptr};

    if (g_app) return; // already initialised

    g_app = new QApplication(dummy_argc, dummy_argv);
    ensure_init();
}

void quartz_run(void) {
    if (g_app) {
        g_app->exec();
    }
}

void quartz_terminate(void) {
    if (g_app) {
        g_app->quit();
    }
}

// ── Window ────────────────────────────────────────────────────────────

int32_t quartz_window_create(const char *title, int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = g_next_id.fetchAndAddOrdered(1);

    QWidget *window = new QWidget();
    window->setWindowTitle(QString::fromUtf8(title));
    window->resize(width, height);

    // Attach close → terminate
    QObject::connect(window, &QWidget::destroyed, [](QObject*) {
        // optional cleanup
    });

    (*g_widgets)[wid] = window;
    return wid;
}

void quartz_window_set_title(int32_t widget_id, const char *title) {
    if (g_widgets->contains(widget_id)) {
        g_widgets->value(widget_id)->setWindowTitle(QString::fromUtf8(title));
    }
}

void quartz_window_show(int32_t widget_id) {
    if (g_widgets->contains(widget_id)) {
        g_widgets->value(widget_id)->show();
    }
}

// ── Button ────────────────────────────────────────────────────────────

int32_t quartz_button_create(const char *title, int32_t x, int32_t y,
                              int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = g_next_id.fetchAndAddOrdered(1);

    QPushButton *button = new QPushButton(QString::fromUtf8(title));
    button->setGeometry(x, y, width, height);
    button->resize(width, height);

    (*g_widgets)[wid] = button;
    return wid;
}

// ── Label ─────────────────────────────────────────────────────────────

int32_t quartz_label_create(const char *text, int32_t x, int32_t y,
                             int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = g_next_id.fetchAndAddOrdered(1);

    QLabel *label = new QLabel(QString::fromUtf8(text));
    label->setGeometry(x, y, width, height);
    label->setAlignment(Qt::AlignLeft | Qt::AlignVCenter);

    (*g_widgets)[wid] = label;
    return wid;
}

// ── Widget hierarchy ──────────────────────────────────────────────────

void quartz_widget_set_parent(int32_t child_id, int32_t parent_id) {
    if (!g_widgets->contains(child_id) || !g_widgets->contains(parent_id))
        return;

    QWidget *child  = g_widgets->value(child_id);
    QWidget *parent = container_of(g_widgets->value(parent_id));

    child->setParent(parent);
    child->show();
}

// ── Widget properties ─────────────────────────────────────────────────

void quartz_widget_set_text(int32_t widget_id, const char *text) {
    if (!g_widgets->contains(widget_id)) return;

    QWidget *widget = g_widgets->value(widget_id);
    QString qText = QString::fromUtf8(text);

    if (QPushButton *btn = qobject_cast<QPushButton*>(widget)) {
        btn->setText(qText);
    } else if (QLabel *lbl = qobject_cast<QLabel*>(widget)) {
        lbl->setText(qText);
    }
}

void quartz_widget_set_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        (*g_callbacks)[widget_id] = callback;
    } else {
        g_callbacks->remove(widget_id);
    }

    if (!g_widgets->contains(widget_id)) return;

    QWidget *widget = g_widgets->value(widget_id);
    if (QPushButton *btn = qobject_cast<QPushButton*>(widget)) {
        // Disconnect any previous connections to avoid duplicates
        btn->disconnect();
        QObject::connect(btn, &QPushButton::clicked, [widget_id]() {
            if (g_callbacks->contains(widget_id)) {
                QuartzCallback cb = g_callbacks->value(widget_id);
                if (cb) cb(widget_id);
            }
        });
    }
}

} // extern "C"
