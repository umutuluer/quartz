require "./lib_quartz"

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
  end
end
