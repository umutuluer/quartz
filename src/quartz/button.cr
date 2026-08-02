require "./control"

module Quartz
  # A push button that fires a callback when clicked.
  class Button < Control
    # Class-level storage so the Crystal GC does not collect callbacks
    # that are passed as C function pointers to the ObjC runtime.
    @@_callbacks = {} of Int32 => ->

    def initialize(text : String, x : Int32, y : Int32, width : Int32, height : Int32)
      handle = LibQuartz.quartz_button_create(text, x, y, width, height)
      super(handle)
    end

    # Updates the button label.
    def text=(value : String)
      LibQuartz.quartz_widget_set_text(@handle, value)
    end

    # Enables or disables the button. A disabled button appears greyed out
    # and does not respond to clicks.
    # (.NET Control.Enabled)
    #
    # ```
    # button.enabled = false
    # ```
    def enabled=(value : Bool)
      LibQuartz.quartz_widget_set_enabled(@handle, value ? 1 : 0)
    end

    # Registers a block to be called when the button is clicked.
    #
    # ```
    # button.on_click { puts "Clicked!" }
    # ```
    def on_click(&block : ->)
      @@_callbacks[@handle] = block
      LibQuartz.quartz_widget_set_callback(@handle, ->Button._dispatch(Int32))
    end

    # Static callback dispatcher — must not capture any local variables
    # so Crystal can convert it to a C function pointer.
    def self._dispatch(widget_id : Int32)
      @@_callbacks[widget_id]?.try(&.call)
    end
  end
end
