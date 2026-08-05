# Low-level C bindings to the platform-specific GUI backend.
#
# Platform backends (selected at compile time by the Makefile):
#   macOS  → ext/quartz_helper_mac.o  (AppKit)
#   Linux  → ext/quartz_helper_gtk.o  (GTK 3) or ext/quartz_helper_qt.o (Qt 5/6)
#   Windows→ ext/quartz_helper_win.o  (Win32 API)
#
# All backends implement the same C API defined in `ext/quartz_helper.h`.
# Each backend compiles to its own object file so that switching
# backends never links against a stale object.
{% if flag?(:darwin) %}
  @[Link(ldflags: "#{__DIR__}/../../ext/quartz_helper_mac.o -framework AppKit -framework Foundation -lobjc")]
{% elsif flag?(:linux) %}
  # Linux link flags. The Makefile is the canonical source of truth
  # (see LDFLAGS_gtk / LDFLAGS_qt) and overrides these via
  # `crystal build --link-flags`. The defaults below let `crystal
  # spec` work out-of-the-box by:
  #   1. Auto-building the matching backend object via `make all`
  #      (no-op if it's already up to date).
  #   2. Resolving the right pkg-config libs at compile time.
  # Pick a non-default backend with:
  #   -Dquartz_backend_gtk   (GTK 3)
  #   -Dquartz_backend_qt5   (Qt 5)
  #   -Dquartz_backend_qt6   (Qt 6, default)
  {% if flag?(:quartz_backend_gtk) %}
    @[Link(ldflags: "`make -C #{__DIR__}/../.. BACKEND=gtk all >/dev/null 2>&1; pkg-config --libs gtk+-3.0 2>/dev/null` #{__DIR__}/../../ext/quartz_helper_gtk.o")]
  {% elsif flag?(:quartz_backend_qt5) %}
    @[Link(ldflags: "`make -C #{__DIR__}/../.. BACKEND=qt QT_VERSION=5 all >/dev/null 2>&1; pkg-config --libs Qt5Widgets 2>/dev/null` #{__DIR__}/../../ext/quartz_helper_qt.o -lstdc++")]
  {% else %}
    @[Link(ldflags: "`make -C #{__DIR__}/../.. BACKEND=qt all >/dev/null 2>&1; pkg-config --libs Qt6Widgets 2>/dev/null` #{__DIR__}/../../ext/quartz_helper_qt.o -lstdc++")]
  {% end %}
{% elsif flag?(:win32) %}
  @[Link(ldflags: "#{__DIR__}/../../ext/quartz_helper_win.o -lgdi32 -luser32 -lcomctl32")]
{% else %}
  @[Link(ldflags: "#{__DIR__}/../../ext/quartz_helper.o")]
{% end %}
lib LibQuartz
  # Callback type: (widget_id : Int32) -> Void
  alias QuartzCallback = (Int32) ->

  # --- Application lifecycle ---
  fun quartz_init : Void
  fun quartz_run : Void
  fun quartz_terminate : Void

  # --- Window ---
  fun quartz_window_create(title : LibC::Char*, width : Int32, height : Int32) : Int32
  fun quartz_window_set_title(widget_id : Int32, title : LibC::Char*) : Void
  fun quartz_window_show(widget_id : Int32) : Void

  # --- Controls ---
  fun quartz_button_create(title : LibC::Char*, x : Int32, y : Int32,
                           width : Int32, height : Int32) : Int32
  fun quartz_label_create(text : LibC::Char*, x : Int32, y : Int32,
                          width : Int32, height : Int32) : Int32
  fun quartz_textbox_create(text : LibC::Char*, x : Int32, y : Int32,
                            width : Int32, height : Int32) : Int32

  # --- Widget hierarchy ---
  fun quartz_widget_set_parent(child_id : Int32, parent_id : Int32) : Void

  # --- Widget properties ---
  fun quartz_widget_set_text(widget_id : Int32, text : LibC::Char*) : Void
  fun quartz_widget_set_callback(widget_id : Int32, callback : QuartzCallback) : Void
  fun quartz_widget_set_enabled(widget_id : Int32, enabled : Int32) : Void

  # --- TextBox-specific ---
  fun quartz_textbox_get_text(widget_id : Int32) : LibC::Char*
  fun quartz_textbox_set_max_length(widget_id : Int32, max_length : Int32) : Void
  fun quartz_textbox_set_read_only(widget_id : Int32, read_only : Int32) : Void
  fun quartz_textbox_set_placeholder(widget_id : Int32, text : LibC::Char*) : Void
  fun quartz_textbox_set_password_char(widget_id : Int32, ch : LibC::Char) : Void
  fun quartz_textbox_set_change_callback(widget_id : Int32, callback : QuartzCallback) : Void

  # --- ListBox-specific ---
  fun quartz_listbox_create(x : Int32, y : Int32,
                            width : Int32, height : Int32) : Int32
  fun quartz_listbox_add_item(widget_id : Int32, text : LibC::Char*) : Void
  fun quartz_listbox_remove_item(widget_id : Int32, index : Int32) : Void
  fun quartz_listbox_clear(widget_id : Int32) : Void
  fun quartz_listbox_get_selected_index(widget_id : Int32) : Int32
  fun quartz_listbox_get_selected_text(widget_id : Int32) : LibC::Char*
  fun quartz_listbox_set_selected_index(widget_id : Int32, index : Int32) : Void
  fun quartz_listbox_get_item_count(widget_id : Int32) : Int32
  fun quartz_listbox_get_item_text(widget_id : Int32, index : Int32) : LibC::Char*
  fun quartz_listbox_set_selection_callback(widget_id : Int32, callback : QuartzCallback) : Void

  # --- Toggle (CheckBox / RadioButton) ---
  fun quartz_checkbox_create(text : LibC::Char*, x : Int32, y : Int32,
                             width : Int32, height : Int32) : Int32
  fun quartz_radiobutton_create(text : LibC::Char*, x : Int32, y : Int32,
                                width : Int32, height : Int32) : Int32
  fun quartz_toggle_get_checked(widget_id : Int32) : Int32
  fun quartz_toggle_set_checked(widget_id : Int32, checked : Int32) : Void
  fun quartz_toggle_set_change_callback(widget_id : Int32, callback : QuartzCallback) : Void
end
