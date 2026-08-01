# Low-level C bindings to the platform-specific GUI backend.
#
# Platform backends (selected at compile time by the Makefile):
#   macOS  → ext/quartz_helper_mac.m  (AppKit)
#   Linux  → ext/quartz_helper_gtk.c  (GTK 3) or ext/quartz_helper_qt.cpp (Qt 5/6)
#   Windows→ ext/quartz_helper_win.c  (Win32 API)
#
# All backends implement the same C API defined in `ext/quartz_helper.h`.
{% if flag?(:darwin) %}
  @[Link(ldflags: "#{__DIR__}/../../ext/quartz_helper.o -framework AppKit -framework Foundation -lobjc")]
{% elsif flag?(:linux) %}
  # Link flags for GTK/Qt are injected by the Makefile via `--link-flags`.
  @[Link(ldflags: "#{__DIR__}/../../ext/quartz_helper.o")]
{% elsif flag?(:win32) %}
  @[Link(ldflags: "#{__DIR__}/../../ext/quartz_helper.o -lgdi32 -luser32 -lcomctl32")]
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

  # --- Widget hierarchy ---
  fun quartz_widget_set_parent(child_id : Int32, parent_id : Int32) : Void

  # --- Widget properties ---
  fun quartz_widget_set_text(widget_id : Int32, text : LibC::Char*) : Void
  fun quartz_widget_set_callback(widget_id : Int32, callback : QuartzCallback) : Void
end
