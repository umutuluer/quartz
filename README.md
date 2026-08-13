<p align="center">
  <img src="assets/logo.png" alt="Quartz logo" width="128" />
</p>

<h1 align="center">Quartz</h1>

<p align="center">
  <strong>A Windows Forms-inspired, cross-platform GUI toolkit for Crystal</strong>
</p>

<p align="center">
  <a href="https://github.com/umutuluer/quartz/actions/workflows/ci.yml"><img src="https://github.com/umutuluer/quartz/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <a href="https://codecov.io/gh/umutuluer/quartz"><img src="https://codecov.io/gh/umutuluer/quartz/branch/main/graph/badge.svg" alt="Coverage" /></a>
  <a href="https://github.com/umutuluer/quartz/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License" /></a>
  <a href="https://crystal-lang.org"><img src="https://img.shields.io/badge/crystal-%3E%3D%201.21.0-black" alt="Crystal" /></a>
  <a href="#platform-support"><img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey" alt="Platforms" /></a>
</p>

---

## ✨ Overview

**Quartz** is a **native, cross-platform GUI toolkit** for the [Crystal](https://crystal-lang.org) programming language. Its API is inspired by **Windows Forms**, making it instantly familiar to developers who have worked with desktop GUI frameworks before.

Quartz does **not** bundle a rendering engine or ship a UI library. Instead, it wraps each platform's **native toolkit** through a thin C bridge, giving you truly native look-and-feel on every OS — for free.

| Platform | Backend               |
| -------- | --------------------- |
| ![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white&style=flat) | **AppKit** (Cocoa)    |
| ![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black&style=flat) | **GTK 3** or **Qt 5/6** |
| ![Windows](https://img.shields.io/badge/Windows-0078D6?logo=windows&logoColor=white&style=flat) | **Win32 API**         |

### 🧪 Tested On

Quartz has been verified to work on the following environments:

| OS | Backend | Status |
| -- | ------- | ------ |
| ![macOS 26](https://img.shields.io/badge/macOS_26-000000?logo=apple&logoColor=white&style=flat) | AppKit | ✅ Working |
| ![CachyOS](https://img.shields.io/badge/CachyOS-00A6D6?logo=archlinux&logoColor=white&style=flat) | GTK 3 | ✅ Working |
| ![CachyOS](https://img.shields.io/badge/CachyOS-00A6D6?logo=archlinux&logoColor=white&style=flat) | Qt 6 | ✅ Working |

---

## 🚀 Quick Start

```crystal
require "quartz"

Quartz::Application.run do |app|
  window = Quartz::Window.new("Hello, Quartz!", 400, 250)

  label = Quartz::Label.new("Welcome! 👋", x: 20, y: 20, width: 360, height: 30)
  window.add_control(label)

  button = Quartz::Button.new("Click Me", x: 20, y: 60, width: 120, height: 32)
  button.on_click { label.text = "Button clicked! 🎉" }
  window.add_control(button)

  window.show
end
```

---

## 📦 Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     quartz:
       github: umutuluer/quartz
   ```

2. Install with [Shards](https://crystal-lang.org/reference/guides/shards.html):

   ```bash
   shards install
   ```

---

## 🔨 Building from Source

Quartz links against a compiled `ext/quartz_helper.o` object file. Use the provided `Makefile` to build it:

```bash
make          # auto-detects your platform (macOS / Linux / Windows)
make mac      # force macOS AppKit backend
make gtk      # force Linux GTK 3 backend
make qt       # force Linux Qt 5/6 backend (QT_VERSION=6 for Qt6)
make win      # force Windows Win32 backend
make clean    # remove build artifacts
```

Then compile your Crystal application as usual:

```bash
shards build
```

---

## 📖 API Reference

### Application Lifecycle

| Method                          | Description                    |
| ------------------------------- | ------------------------------ |
| `Quartz::Application.run { }` | Starts the application loop    |
| `Quartz::Application.exit`    | Terminates the application     |

### Window

| Method                                      | Description              |
| ------------------------------------------- | ------------------------ |
| `Window.new(title, width, height)`         | Creates a new window     |
| `window.title = "New Title"`               | Changes the window title |
| `window.show`                              | Shows the window         |
| `window.add_control(control)`              | Adds a child control     |

### Button

| Method                                          | Description                     |
| ----------------------------------------------- | ------------------------------- |
| `Button.new(text, x, y, width, height)`        | Creates a push button           |
| `button.text = "Save"`                         | Updates the button label        |
| `button.on_click { }`                          | Registers a click callback      |

### Label

| Method                                          | Description              |
| ----------------------------------------------- | ----------------------- |
| `Label.new(text, x, y, width, height)`         | Creates a read-only label |
| `label.text`                                   | Gets the current text     |
| `label.text = "Updated"`                       | Updates the label text    |

### TextBox

| Method                                          | Description              |
| ----------------------------------------------- | ----------------------- |
| `TextBox.new(text, x, y, width, height)`       | Creates a text input box |
| `textbox.text`                                 | Gets the current text    |
| `textbox.placeholder = "..."`                  | Sets placeholder text    |
| `textbox.password_char = '*'`                  | Sets password masking    |
| `textbox.on_text_changed { }`                  | Registers change event   |

### ListBox

| Method                                          | Description                    |
| ----------------------------------------------- | ------------------------------ |
| `ListBox.new(x, y, width, height)`             | Creates a scrollable list      |
| `listbox.add_item("Item")`                     | Adds an item to the list       |
| `listbox.remove_item(index)`                   | Removes the item at index      |
| `listbox.clear`                                | Removes all items              |
| `listbox.selected_index`                       | Gets / sets selected index     |
| `listbox.selected_text`                        | Gets selected item text or nil |
| `listbox.item_count`                           | Returns the number of items    |
| `listbox.item_text(index)`                     | Gets the text at given index   |
| `listbox.on_selection_changed { }`             | Registers selection change     |

### ComboBox

| Method                                          | Description                          |
| ----------------------------------------------- | ------------------------------------ |
| `ComboBox.new(x, y, w, h, editable: false)`    | Creates a dropdown (editable = text input) |
| `combo.add_item("Item")`                       | Adds an item                          |
| `combo.remove_item(index)`                     | Removes the item at index             |
| `combo.clear`                                  | Removes all items                     |
| `combo.item_count`                             | Returns the number of items           |
| `combo.item_text(index)`                       | Gets the text at given index          |
| `combo.selected_index`                         | Gets / sets selected index            |
| `combo.selected_text`                          | Gets selected item text or nil        |
| `combo.text`                                   | Gets the current text                 |
| `combo.text = "..."`                           | Sets the current text                 |
| `combo.dropped_down?`                          | Whether dropdown is open              |
| `combo.dropped_down = true`                    | Opens / closes the dropdown           |
| `combo.on_selection_changed { }`               | Registers selection change            |
| `combo.on_text_changed { }`                    | Registers edit-text change            |

### FileDialog

Abstract base for file dialogs. Concrete classes: `OpenFileDialog`, `SaveFileDialog`.

| Method                                | Description                          |
| ------------------------------------- | ------------------------------------ |
| `dialog.title`                        | Dialog window title                  |
| `dialog.filter`                       | WinForms-style filter (`"Text (*.txt)\|*.txt\|All (*.*)\|*.*"`) |
| `dialog.initial_directory`            | Starting directory                   |
| `dialog.file_name`                    | Initial file name (SaveFileDialog)   |
| `dialog.default_ext`                  | Default extension                    |
| `dialog.show_dialog(owner : Window?)` | Blocking modal; returns `String?` (nil = cancel) |

`OpenFileDialog` additionally has `multiselect : Bool`. `SaveFileDialog` additionally has `overwrite_prompt : Bool` (default true).

> Multiselect MVP: only the first selected file is returned. Full `Array(String)?` API coming later.

### StackLayout

Linear layout: vertical ya da horizontal stack. Saf Crystal sınıfıdır (Control'den türemez); çocukları
`add(control, width, height)` ile ölçüleriyle birlikte ekler, `relayout` ile yeniden konumlandırır.

| Method | Description |
| --- | --- |
| `layout = StackLayout.new(orientation, padding, spacing)` | orientation `:vertical` veya `:horizontal`, defaults: VBox, 0, 0 |
| `layout.add(control, width, height) : self` | Zincirleme ekleme |
| `layout.remove(control) : self` | Çıkar + relayout |
| `layout.clear : self` | Tüm çocukları sil |
| `layout.size : Int32` | Çocuk sayısı |
| `layout.relayout : self` | Tüm çocukları yeniden konumlandır (manuel tetikleme; auto-resize bir sonraki sürümde) |

Vertical: çocuklar dikey; her biri `parent_width - 2*padding` kadar genişlikte.
Horizontal: çocuklar yatay; her biri belirtilen width kadar, `parent_height - 2*padding` yüksekliğinde.

> **Not:** Resize'da otomatik reflay henüz yok. Pencere yeniden boyutlandırılırsa `layout.relayout` manuel çağrılmalı. Hook altyapısı (`Window#on_resize`) bir sonraki sürümde eklenecek.

### CheckBox

| Method                                             | Description                       |
| ------------------------------------------------- | --------------------------------- |
| `CheckBox.new(text, x, y, width, height)`        | Creates a checkbox                |
| `CheckBox.new(text, x, y, w, h, checked: true)`  | Creates a pre-checked checkbox    |
| `check_box.text = "Enable"`                      | Updates the label                 |
| `check_box.checked`                              | Returns whether checked           |
| `check_box.checked = true`                       | Sets the checked state            |
| `check_box.on_checked_changed { }`               | Registers state-change callback   |

### RadioButton

| Method                                                | Description                            |
| ---------------------------------------------------- | -------------------------------------- |
| `RadioButton.new(text, x, y, width, height)`        | Creates a radio button                 |
| `RadioButton.new(text, x, y, w, h, checked: true)`  | Creates a pre-selected radio button    |
| `radio_button.text = "Option"`                      | Updates the label                      |
| `radio_button.checked`                              | Returns whether selected               |
| `radio_button.checked = true`                       | Selects (unchecks siblings)            |
| `radio_button.on_checked_changed { }`               | Registers state-change callback        |

> Radio buttons in the same window are mutually exclusive — selecting one automatically deselects others. Radio buttons in different windows are independent.

### MenuBar / MenuItem / MenuSeparator / ContextMenu

| Class | Method |
|---|---|
| `MenuBar.new` | Create top-level menubar |
| `MenuBar#add_item(item)` / `add_item(text, &block)` | Add menu item |
| `MenuBar#add_separator` | Add visual separator |
| `MenuBar#items` | Returns list of added items |
| `Window#menu_bar=` | Attach menubar to window |
| `MenuItem.new(text)` | Create menu item with label |
| `MenuItem#on_click(&block)` | Register click callback |
| `MenuSeparator.new` | Create separator |
| `ContextMenu.new` | Create right-click menu |
| `Control#context_menu=` | Attach context menu to widget |

> **MVP limitations:**
> - Submenu (nested menus) not supported — flat menubar only
> - Shortcuts, checked items — out of MVP scope
> - macOS menubar is app-global (last assigned wins); per-window future work
> - Qt menubar requires QMainWindow promotion (separate backend task)

> **⚠️ Submenu support is OUT of the MVP — flat menubar only.** A menubar currently holds a single level of items; nested/submenus require an extra C API (`quartz_menu_item_set_submenu` or similar) that is deferred to a later wave. `MenuBar` instances are designed to be reused as submenu containers once that lands.

> **macOS limitation:** the menubar is **app-global** (`[NSApp setMainMenu:]`). With multiple windows the last `window.menu_bar=` wins. This matches the documented Wave-1b risk in `MENU_PLAN.md`.

> **Qt limitation:** Qt menubar ataması, QMainWindow terfisi ayrı bir dalgada eklenecek. Context menu (sağ tık) Qt'de çalışır.

> All controls inherit from `Control`, which provides the low-level `handle` and `parent` properties.

---

## 🧪 Examples

Run the included hello-world example:

```bash
make examples
./bin/hello_world
```

Example source: [`examples/hello_world.cr`](examples/hello_world.cr)

Run the TextBox demo:

```bash
crystal build examples/textbox_example.cr -o bin/textbox_example
./bin/textbox_example
```

Example source: [`examples/textbox_example.cr`](examples/textbox_example.cr)

Run the ListBox demo:

```bash
crystal build examples/listbox_example.cr -o bin/listbox_example
./bin/listbox_example
```

Example source: [`examples/listbox_example.cr`](examples/listbox_example.cr)

Run the OpenFileDialog demo:

```bash
crystal build examples/openfiledialog_example.cr -o bin/openfiledialog_example
./bin/openfiledialog_example
```

Example source: [`examples/openfiledialog_example.cr`](examples/openfiledialog_example.cr)

Run the SaveFileDialog demo:

```bash
crystal build examples/savefiledialog_example.cr -o bin/savefiledialog_example
./bin/savefiledialog_example
```

Example source: [`examples/savefiledialog_example.cr`](examples/savefiledialog_example.cr)

Run the Layout demo:

```bash
crystal build examples/layout_example.cr -o bin/layout_example
./bin/layout_example
```

Example source: [`examples/layout_example.cr`](examples/layout_example.cr)

Run the ComboBox demo:

```bash
crystal build examples/combobox_example.cr -o bin/combobox_example
./bin/combobox_example
```

Example source: [`examples/combobox_example.cr`](examples/combobox_example.cr)

Run the CheckBox demo:

```bash
crystal build examples/checkbox_example.cr -o bin/checkbox_example
./bin/checkbox_example
```

Example source: [`examples/checkbox_example.cr`](examples/checkbox_example.cr)

Run the RadioButton demo:

```bash
crystal build examples/radiobutton_example.cr -o bin/radiobutton_example
./bin/radiobutton_example
```

Example source: [`examples/radiobutton_example.cr`](examples/radiobutton_example.cr)

Run the Menu demo:

```bash
crystal build examples/menu_example.cr -o bin/menu_example
./bin/menu_example
```

Example source: [`examples/menu_example.cr`](examples/menu_example.cr)

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────┐
│            Crystal (src/)                 │
│  Application · Window · Button · Label    │
│       TextBox · ListBox · ComboBox          │
│  CheckBox · FileDialog · RadioButton ·     │
│  MenuBar · MenuItem · MenuSeparator ·      │
│            ContextMenu                       │
│            StackLayout                       │
│                  │                        │
│            lib_quartz.cr                  │
│          (C bindings via @[Link])         │
└──────────────────┬───────────────────────┘
                   │  quartz_helper.h
┌──────────────────┴───────────────────────┐
│          C bridge (ext/)                  │
│  quartz_helper_mac.m  ──  AppKit         │
│  quartz_helper_gtk.c  ──  GTK 3          │
│  quartz_helper_qt.cpp ──  Qt 5/6         │
│  quartz_helper_win.c  ──  Win32 API      │
└──────────────────────────────────────────┘
```

---

## 🗺️ Roadmap

- [x] macOS AppKit backend
- [x] Linux GTK 3 backend
- [x] Linux Qt 5/6 backend
- [x] Windows Win32 backend
- [x] TextBox / input controls
- [x] ListBox
- [x] CheckBox, RadioButton
- [x] ComboBox / DropDown
- [x] File dialogs
- [x] Layout managers — Stack MVP
- [ ] Layout managers (Flow, Grid)
- [x] Menu bar & context menus (C layer: AppKit/GTK/Win32/Qt items + context menus; Qt menubar attach deferred — QMainWindow promotion. Submenus out of MVP.)
- [x] Comprehensive test suite

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Open a Pull Request

Please make sure your code follows the existing style and includes appropriate specs.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Umut ULUER** — [@umutuluer](https://github.com/umutuluer)

---

<p align="center">
  <sub>Built with ❤️ and Crystal</sub>
</p>

## Testing

Quartz ships with **259 deterministic spec examples** that run in under 500ms across 4 native backends.

```bash
make spec          # run the full suite (default backend: mac/AppKit)
make lint          # ameba static analysis
make format        # crystal tool format --check
make examples      # build the 10 example programs
```

The test suite covers:

- **Crystal-level coverage** — every public method on every widget
- **Native callback routing** — C-level trampoline helpers fire real callbacks through the 4 backends' callback tables
- **Lifecycle** — show/close, multi-window ID uniqueness, re-parenting, queryability after operations
- **Edge cases** — Unicode (emoji 🚀, RTL عربية, ZWJ 👨‍👩‍👧), 10k-char strings, zero/negative dimensions, empty strings
- **Geometry** — StackLayout pixel-position asserts via `quartz_widget_get_bounds`
- **Modal dialogs** — `OpenFileDialog`/`SaveFileDialog` mocked through a C-level seam (`quartz_test_dialog_set_mode` + `QUARTZ_TEST_DIALOG_PATH`)

CI matrix runs the full suite on all 4 backends: **macOS/AppKit**, **Linux/GTK3** (under xvfb), **Linux/Qt5** (offscreen QPA), **Windows/Win32**.

Spec files live under `spec/` (unit specs in `spec/unit/`, helpers in `spec/support/`). The C-level test helpers (`quartz_test_fire_*`, `quartz_widget_get_bounds`, `quartz_test_dialog_set_mode`) are declared in `ext/quartz_helper.h` and implemented in all 4 backends.
