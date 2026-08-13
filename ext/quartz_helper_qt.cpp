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
#include <QFileDialog>
#include <QWidget>
#include <QPushButton>
#include <QCheckBox>
#include <QRadioButton>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QComboBox>
#include <QAbstractButton>
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

// Change callback registry (for TextBox text changes)
static QMap<int32_t, QuartzCallback> *g_change_callbacks = nullptr;

// Selection callback registry (for ListBox selection changes)
static QMap<int32_t, QuartzCallback> *g_selection_callbacks = nullptr;

// Text callback registry (for ComboBox text changes)
static QMap<int32_t, QuartzCallback> *g_text_callbacks = nullptr;

// Toggle change callback registry (for CheckBox / RadioButton)
static QMap<int32_t, QuartzCallback> *g_toggle_callbacks = nullptr;

// Thread-safe ID counter
static QAtomicInt g_next_id(1);

void ensure_init() {
    if (!g_widgets) {
        g_widgets   = new QMap<int32_t, QWidget*>();
        g_callbacks = new QMap<int32_t, QuartzCallback>();
        g_change_callbacks = new QMap<int32_t, QuartzCallback>();
        g_selection_callbacks = new QMap<int32_t, QuartzCallback>();
        g_text_callbacks = new QMap<int32_t, QuartzCallback>();
        g_toggle_callbacks = new QMap<int32_t, QuartzCallback>();
    }
}

// Helper: get the QWidget content container from a window
// QWidget itself is the window AND the container.
// Children are added directly to the window widget.
QWidget* container_of(QWidget *widget) {
    return widget; // Qt: windows ARE containers
}

// Helper: resolve an owner widget from its registry id
QWidget* findOwnerWidget(int32_t owner_widget_id) {
    if (owner_widget_id < 0) return nullptr;
    if (!g_widgets) return nullptr;
    auto it = g_widgets->find(owner_widget_id);
    if (it == g_widgets->end()) return nullptr;
    return it.value();
}

// Helper: convert WinForms "display|pattern|..." filter to Qt ";;" format
QString convertFilter(const char* quartz_filter) {
    if (!quartz_filter || !*quartz_filter) return QString();
    QString src = QString::fromUtf8(quartz_filter);
    QStringList parts = src.split('|');
    QString result;
    // Pairs: display[0], pattern[1], display[2], pattern[3], ...
    for (int i = 0; i + 1 < parts.size(); i += 2) {
        if (i > 0) result += ";;";
        result += parts[i] + "(" + parts[i+1] + ")";
    }
    return result;
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

// ── TextBox ───────────────────────────────────────────────────────────

int32_t quartz_textbox_create(const char *text, int32_t x, int32_t y,
                               int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = g_next_id.fetchAndAddOrdered(1);

    QLineEdit *edit = new QLineEdit(QString::fromUtf8(text));
    edit->setGeometry(x, y, width, height);

    (*g_widgets)[wid] = edit;
    return wid;
}

const char* quartz_textbox_get_text(int32_t widget_id) {
    static QByteArray buffer;
    if (g_widgets->contains(widget_id)) {
        QWidget *widget = g_widgets->value(widget_id);
        if (QLineEdit *edit = qobject_cast<QLineEdit*>(widget)) {
            buffer = edit->text().toUtf8();
            return buffer.constData();
        }
    }
    return "";
}

void quartz_textbox_set_max_length(int32_t widget_id, int32_t max_length) {
    if (!g_widgets->contains(widget_id)) return;
    QWidget *widget = g_widgets->value(widget_id);
    if (QLineEdit *edit = qobject_cast<QLineEdit*>(widget)) {
        edit->setMaxLength(max_length);
    }
}

void quartz_textbox_set_read_only(int32_t widget_id, int32_t read_only) {
    if (!g_widgets->contains(widget_id)) return;
    QWidget *widget = g_widgets->value(widget_id);
    if (QLineEdit *edit = qobject_cast<QLineEdit*>(widget)) {
        edit->setReadOnly(read_only ? true : false);
    }
}

void quartz_textbox_set_placeholder(int32_t widget_id, const char* text) {
    if (!g_widgets->contains(widget_id)) return;
    QWidget *widget = g_widgets->value(widget_id);
    if (QLineEdit *edit = qobject_cast<QLineEdit*>(widget)) {
        edit->setPlaceholderText(QString::fromUtf8(text));
    }
}

void quartz_textbox_set_password_char(int32_t widget_id, char ch) {
    if (!g_widgets->contains(widget_id)) return;
    QWidget *widget = g_widgets->value(widget_id);
    if (QLineEdit *edit = qobject_cast<QLineEdit*>(widget)) {
        edit->setEchoMode(QLineEdit::Password);
    }
}

void quartz_textbox_set_change_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        (*g_change_callbacks)[widget_id] = callback;
    } else {
        g_change_callbacks->remove(widget_id);
    }

    if (!g_widgets->contains(widget_id)) return;
    QWidget *widget = g_widgets->value(widget_id);
    if (QLineEdit *edit = qobject_cast<QLineEdit*>(widget)) {
        QObject::connect(edit, &QLineEdit::textChanged, [widget_id](const QString &) {
            if (g_change_callbacks->contains(widget_id)) {
                QuartzCallback cb = g_change_callbacks->value(widget_id);
                if (cb) cb(widget_id);
            }
        });
    }
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

void quartz_widget_set_bounds(int32_t widget_id, int32_t x, int32_t y,
                              int32_t width, int32_t height) {
    auto it = g_widgets->find(widget_id);
    if (it == g_widgets->end()) return;
    QWidget *widget = it.value();
    if (!widget) return;
    widget->setGeometry(x, y, width, height);
}

// ── Widget properties ─────────────────────────────────────────────────

void quartz_widget_set_text(int32_t widget_id, const char *text) {
    if (!g_widgets->contains(widget_id)) return;

    QWidget *widget = g_widgets->value(widget_id);
    QString qText = QString::fromUtf8(text);

    if (QPushButton *btn = qobject_cast<QPushButton*>(widget)) {
        btn->setText(qText);
    } else if (QAbstractButton *abtn = qobject_cast<QAbstractButton*>(widget)) {
        // CheckBox / RadioButton
        abtn->setText(qText);
    } else if (QLabel *lbl = qobject_cast<QLabel*>(widget)) {
        lbl->setText(qText);
    } else if (QLineEdit *edit = qobject_cast<QLineEdit*>(widget)) {
        edit->setText(qText);
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

void quartz_widget_set_enabled(int32_t widget_id, int32_t enabled) {
    if (g_widgets->contains(widget_id)) {
        g_widgets->value(widget_id)->setEnabled(enabled ? true : false);
    }
}

// ── ListBox ────────────────────────────────────────────────────────────

int32_t quartz_listbox_create(int32_t x, int32_t y,
                               int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = g_next_id.fetchAndAddOrdered(1);

    QListWidget *listWidget = new QListWidget();
    listWidget->setGeometry(x, y, width, height);

    (*g_widgets)[wid] = listWidget;
    return wid;
}

void quartz_listbox_add_item(int32_t widget_id, const char* text) {
    if (!g_widgets->contains(widget_id)) return;
    QWidget *widget = g_widgets->value(widget_id);
    if (QListWidget *list = qobject_cast<QListWidget*>(widget)) {
        list->addItem(QString::fromUtf8(text));
    }
}

void quartz_listbox_remove_item(int32_t widget_id, int32_t index) {
    if (!g_widgets->contains(widget_id)) return;
    QWidget *widget = g_widgets->value(widget_id);
    if (QListWidget *list = qobject_cast<QListWidget*>(widget)) {
        if (index >= 0 && index < list->count()) {
            QListWidgetItem *item = list->takeItem(index);
            delete item;
        }
    }
}

void quartz_listbox_clear(int32_t widget_id) {
    if (!g_widgets->contains(widget_id)) return;
    QWidget *widget = g_widgets->value(widget_id);
    if (QListWidget *list = qobject_cast<QListWidget*>(widget)) {
        list->clear();
    }
}

int32_t quartz_listbox_get_selected_index(int32_t widget_id) {
    if (!g_widgets->contains(widget_id)) return -1;
    QWidget *widget = g_widgets->value(widget_id);
    if (QListWidget *list = qobject_cast<QListWidget*>(widget)) {
        return list->currentRow();
    }
    return -1;
}

const char* quartz_listbox_get_selected_text(int32_t widget_id) {
    static QByteArray buffer;
    if (!g_widgets->contains(widget_id)) return NULL;
    QWidget *widget = g_widgets->value(widget_id);
    if (QListWidget *list = qobject_cast<QListWidget*>(widget)) {
        QListWidgetItem *item = list->currentItem();
        if (item) {
            buffer = item->text().toUtf8();
            return buffer.constData();
        }
    }
    return NULL;
}

void quartz_listbox_set_selected_index(int32_t widget_id, int32_t index) {
    if (!g_widgets->contains(widget_id)) return;
    QWidget *widget = g_widgets->value(widget_id);
    if (QListWidget *list = qobject_cast<QListWidget*>(widget)) {
        list->setCurrentRow(index);
    }
}

int32_t quartz_listbox_get_item_count(int32_t widget_id) {
    if (!g_widgets->contains(widget_id)) return 0;
    QWidget *widget = g_widgets->value(widget_id);
    if (QListWidget *list = qobject_cast<QListWidget*>(widget)) {
        return list->count();
    }
    return 0;
}

const char* quartz_listbox_get_item_text(int32_t widget_id, int32_t index) {
    static QByteArray buffer;
    if (!g_widgets->contains(widget_id)) return "";
    QWidget *widget = g_widgets->value(widget_id);
    if (QListWidget *list = qobject_cast<QListWidget*>(widget)) {
        if (index >= 0 && index < list->count()) {
            buffer = list->item(index)->text().toUtf8();
            return buffer.constData();
        }
    }
    return "";
}

void quartz_listbox_set_selection_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        (*g_selection_callbacks)[widget_id] = callback;
    } else {
        g_selection_callbacks->remove(widget_id);
    }

    if (!g_widgets->contains(widget_id)) return;
    QWidget *widget = g_widgets->value(widget_id);
    if (QListWidget *list = qobject_cast<QListWidget*>(widget)) {
        QObject::connect(list, &QListWidget::currentRowChanged, [widget_id](int /*row*/) {
            if (g_selection_callbacks->contains(widget_id)) {
                QuartzCallback cb = g_selection_callbacks->value(widget_id);
                if (cb) cb(widget_id);
            }
        });
    }
}

// ── ComboBox ───────────────────────────────────────────────────────────

int32_t quartz_combobox_create(int32_t x, int32_t y,
                               int32_t w, int32_t h, int32_t editable) {
    ensure_init();
    int32_t wid = g_next_id.fetchAndAddOrdered(1);

    QComboBox *combo = new QComboBox();
    combo->setEditable(editable ? true : false);
    combo->setGeometry(x, y, w, h);

    QObject::connect(combo, QOverload<int>::of(&QComboBox::currentIndexChanged),
                     [wid](int /*index*/) {
                         if (g_selection_callbacks->contains(wid)) {
                             QuartzCallback cb = g_selection_callbacks->value(wid);
                             if (cb) cb(wid);
                         }
                     });
    QObject::connect(combo, &QComboBox::currentTextChanged,
                     [wid](const QString & /*text*/) {
                         if (g_text_callbacks->contains(wid)) {
                             QuartzCallback cb = g_text_callbacks->value(wid);
                             if (cb) cb(wid);
                         }
                     });

    (*g_widgets)[wid] = combo;
    return wid;
}

void quartz_combobox_add_item(int32_t wid, const char* text) {
    if (!g_widgets->contains(wid)) return;
    QWidget *widget = g_widgets->value(wid);
    if (QComboBox *combo = qobject_cast<QComboBox*>(widget)) {
        combo->addItem(QString::fromUtf8(text));
    }
}

void quartz_combobox_remove_item(int32_t wid, int32_t index) {
    if (!g_widgets->contains(wid)) return;
    QWidget *widget = g_widgets->value(wid);
    if (QComboBox *combo = qobject_cast<QComboBox*>(widget)) {
        if (index >= 0 && index < combo->count()) {
            combo->removeItem(index);
        }
    }
}

void quartz_combobox_clear(int32_t wid) {
    if (!g_widgets->contains(wid)) return;
    QWidget *widget = g_widgets->value(wid);
    if (QComboBox *combo = qobject_cast<QComboBox*>(widget)) {
        combo->clear();
    }
}

int32_t quartz_combobox_get_item_count(int32_t wid) {
    if (!g_widgets->contains(wid)) return 0;
    QWidget *widget = g_widgets->value(wid);
    if (QComboBox *combo = qobject_cast<QComboBox*>(widget)) {
        return combo->count();
    }
    return 0;
}

const char* quartz_combobox_get_item_text(int32_t wid, int32_t index) {
    static QByteArray buffer;
    if (!g_widgets->contains(wid)) return "";
    QWidget *widget = g_widgets->value(wid);
    if (QComboBox *combo = qobject_cast<QComboBox*>(widget)) {
        if (index >= 0 && index < combo->count()) {
            buffer = combo->itemText(index).toUtf8();
            return buffer.constData();
        }
    }
    return "";
}

int32_t quartz_combobox_get_selected_index(int32_t wid) {
    if (!g_widgets->contains(wid)) return -1;
    QWidget *widget = g_widgets->value(wid);
    if (QComboBox *combo = qobject_cast<QComboBox*>(widget)) {
        return combo->currentIndex();
    }
    return -1;
}

void quartz_combobox_set_selected_index(int32_t wid, int32_t index) {
    if (!g_widgets->contains(wid)) return;
    QWidget *widget = g_widgets->value(wid);
    if (QComboBox *combo = qobject_cast<QComboBox*>(widget)) {
        combo->setCurrentIndex(index);
    }
}

const char* quartz_combobox_get_text(int32_t wid) {
    static QByteArray buffer;
    if (!g_widgets->contains(wid)) return "";
    QWidget *widget = g_widgets->value(wid);
    if (QComboBox *combo = qobject_cast<QComboBox*>(widget)) {
        buffer = combo->currentText().toUtf8();
        return buffer.constData();
    }
    return "";
}

void quartz_combobox_set_text(int32_t wid, const char* text) {
    if (!g_widgets->contains(wid)) return;
    QWidget *widget = g_widgets->value(wid);
    if (QComboBox *combo = qobject_cast<QComboBox*>(widget)) {
        combo->setEditText(QString::fromUtf8(text));
    }
}

int32_t quartz_combobox_get_dropped_down(int32_t wid) {
    if (!g_widgets->contains(wid)) return 0;
    QWidget *widget = g_widgets->value(wid);
    if (QComboBox *combo = qobject_cast<QComboBox*>(widget)) {
        return combo->view()->isVisible() ? 1 : 0;
    }
    return 0;
}

void quartz_combobox_set_dropped_down(int32_t wid, int32_t dropped) {
    if (!g_widgets->contains(wid)) return;
    QWidget *widget = g_widgets->value(wid);
    if (QComboBox *combo = qobject_cast<QComboBox*>(widget)) {
        if (dropped) {
            combo->showPopup();
        } else {
            combo->hidePopup();
        }
    }
}

void quartz_combobox_set_selection_callback(int32_t wid, QuartzCallback cb) {
    if (cb) {
        (*g_selection_callbacks)[wid] = cb;
    } else {
        g_selection_callbacks->remove(wid);
    }
}

void quartz_combobox_set_text_callback(int32_t wid, QuartzCallback cb) {
    if (cb) {
        (*g_text_callbacks)[wid] = cb;
    } else {
        g_text_callbacks->remove(wid);
    }
}

// ── CheckBox ────────────────────────────────────────────────────────────

int32_t quartz_checkbox_create(const char *text, int32_t x, int32_t y,
                                int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = g_next_id.fetchAndAddOrdered(1);

    QCheckBox *check = new QCheckBox(QString::fromUtf8(text));
    check->setGeometry(x, y, width, height);

    (*g_widgets)[wid] = check;
    return wid;
}

// ── RadioButton ─────────────────────────────────────────────────────────

int32_t quartz_radiobutton_create(const char *text, int32_t x, int32_t y,
                                   int32_t width, int32_t height) {
    ensure_init();
    int32_t wid = g_next_id.fetchAndAddOrdered(1);

    QRadioButton *radio = new QRadioButton(QString::fromUtf8(text));
    radio->setGeometry(x, y, width, height);
    // QRadioButton is auto-exclusive within the same parent by default

    (*g_widgets)[wid] = radio;
    return wid;
}

// ── Toggle state (shared by CheckBox and RadioButton) ───────────────────

int32_t quartz_toggle_get_checked(int32_t widget_id) {
    if (!g_widgets->contains(widget_id)) return 0;
    QWidget *widget = g_widgets->value(widget_id);
    if (QAbstractButton *btn = qobject_cast<QAbstractButton*>(widget)) {
        return btn->isChecked() ? 1 : 0;
    }
    return 0;
}

void quartz_toggle_set_checked(int32_t widget_id, int32_t checked) {
    if (!g_widgets->contains(widget_id)) return;
    QWidget *widget = g_widgets->value(widget_id);
    if (QAbstractButton *btn = qobject_cast<QAbstractButton*>(widget)) {
        bool newState = checked ? true : false;
        if (btn->isChecked() != newState) {
            btn->setChecked(newState);
            // QAbstractButton::setChecked fires toggled(bool) automatically,
            // which dispatches through the lambda callback below
        }
    }
}

void quartz_toggle_set_change_callback(int32_t widget_id, QuartzCallback callback) {
    if (callback) {
        (*g_toggle_callbacks)[widget_id] = callback;
    } else {
        g_toggle_callbacks->remove(widget_id);
    }

    if (!g_widgets->contains(widget_id)) return;
    QWidget *widget = g_widgets->value(widget_id);
    if (QAbstractButton *btn = qobject_cast<QAbstractButton*>(widget)) {
        // Disconnect previous toggled connections to avoid duplicates
        QObject::disconnect(btn, &QAbstractButton::toggled, nullptr, nullptr);
        QObject::connect(btn, &QAbstractButton::toggled, [widget_id](bool) {
            if (g_toggle_callbacks->contains(widget_id)) {
                QuartzCallback cb = g_toggle_callbacks->value(widget_id);
                if (cb) cb(widget_id);
            }
        });
    }
}

// ── File dialogs ──────────────────────────────────────────────────────

const char* quartz_open_file_dialog(const char* title, const char* filter,
                                    const char* initial_directory, const char* default_ext,
                                    int32_t multiselect, int32_t owner_widget_id) {
    static QByteArray buffer;
    buffer.clear();

    QWidget *owner = findOwnerWidget(owner_widget_id);
    QString qtFilter = convertFilter(filter);
    QString dir = initial_directory ? QString::fromUtf8(initial_directory) : QString();
    QString selectedFilter;
    QStringList files;

    if (multiselect) {
        files = QFileDialog::getOpenFileNames(owner,
            title ? QString::fromUtf8(title) : QString(),
            dir, qtFilter, &selectedFilter);
    } else {
        QString file = QFileDialog::getOpenFileName(owner,
            title ? QString::fromUtf8(title) : QString(),
            dir, qtFilter, &selectedFilter);
        if (!file.isEmpty()) files << file;
    }

    if (files.isEmpty()) return nullptr;
    buffer = files.first().toUtf8();
    (void)default_ext;  // Qt filter pattern'den gelir
    return buffer.constData();
}

const char* quartz_save_file_dialog(const char* title, const char* filter,
                                    const char* initial_directory, const char* default_ext,
                                    const char* file_name, int32_t overwrite_prompt,
                                    int32_t owner_widget_id) {
    static QByteArray buffer;
    buffer.clear();

    QWidget *owner = findOwnerWidget(owner_widget_id);
    QString qtFilter = convertFilter(filter);
    QString dir = initial_directory ? QString::fromUtf8(initial_directory) : QString();
    QString selectedFilter;
    QFileDialog::Options options = QFileDialog::DontConfirmOverwrite;
    if (overwrite_prompt) {
        options = 0;  // default = confirm
    }

    QString file = QFileDialog::getSaveFileName(owner,
        title ? QString::fromUtf8(title) : QString(),
        dir, qtFilter, &selectedFilter, options);

    if (file.isEmpty()) return nullptr;
    buffer = file.toUtf8();
    (void)file_name;  // Qt, dir parametresinden path'i alır; dosya adı için ek API yok
    (void)default_ext;  // Qt filter pattern'den gelir
    return buffer.constData();
}

} // extern "C"
