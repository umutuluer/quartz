require "./lib_quartz"
require "./context_menu"

module Quartz
  # Base class for all UI elements (Window, Button, Label, etc.).
  #
  # Every control wraps a native AppKit widget identified by an opaque
  # `handle` (Int32). Subclasses expose type-specific behaviour (e.g.
  # Button provides `on_click`).
  abstract class Control
    # Low-level widget handle passed to `LibQuartz` functions.
    getter handle : Int32

    # The parent control that contains this widget, or `nil` if it has
    # not been added to a window yet.
    property parent : Control?

    def initialize(@handle : Int32)
      @parent = nil
    end

    # Attaches a right-click (context) menu to this control, or detaches
    # it when `nil` is passed. Returns `self` to enable method chaining.
    #
    # Passing a nil menu calls `quartz_widget_set_contextmenu(handle, 0)`;
    # on backends without a native detach path (e.g. macOS AppKit) this is
    # a safe no-op, so a previously bound menu cannot be removed in the MVP.
    def context_menu=(menu : ContextMenu?) : self
      if menu
        LibQuartz.quartz_widget_set_contextmenu(@handle, menu.handle)
      else
        # Detach not supported in MVP — no-op on backends without a
        # null-safe detach API.
        LibQuartz.quartz_widget_set_contextmenu(@handle, 0)
      end
      self
    end
  end
end
