require "./control"

module Quartz
  # A checkbox that can be toggled on or off.
  # (.NET CheckBox)
  #
  # ```
  # check = Quartz::CheckBox.new("Enable feature", 10, 10, 200, 25)
  # check.on_checked_changed { puts "Checked: #{check.checked}" }
  # ```
  class CheckBox < Control
    # Class-level storage so the Crystal GC does not collect callbacks
    # that are passed as C function pointers to the native runtime.
    @@_callbacks = {} of Int32 => ->

    def initialize(text : String, x : Int32, y : Int32, width : Int32, height : Int32, checked : Bool = false)
      handle = LibQuartz.quartz_checkbox_create(text, x, y, width, height)
      super(handle)
      self.checked = checked if checked
    end

    # Updates the label displayed next to the checkbox.
    def text=(value : String)
      LibQuartz.quartz_widget_set_text(@handle, value)
    end

    # Returns whether the checkbox is currently checked.
    # (.NET CheckBox.Checked)
    def checked : Bool
      LibQuartz.quartz_toggle_get_checked(@handle) != 0
    end

    # Sets the checked state. Fires on_checked_changed only when
    # the value actually changes.
    # (.NET CheckBox.Checked)
    def checked=(value : Bool)
      LibQuartz.quartz_toggle_set_checked(@handle, value ? 1 : 0)
    end

    # Enables or disables the checkbox.
    # (.NET Control.Enabled)
    def enabled=(value : Bool)
      LibQuartz.quartz_widget_set_enabled(@handle, value ? 1 : 0)
    end

    # Registers a block to be called when the checked state changes.
    # (.NET CheckBox.CheckedChanged)
    #
    # ```
    # check.on_checked_changed { puts check.checked }
    # ```
    def on_checked_changed(&block : ->)
      @@_callbacks[@handle] = block
      LibQuartz.quartz_toggle_set_change_callback(@handle, ->CheckBox._dispatch(Int32))
    end

    # Static callback dispatcher — must not capture any local variables
    # so Crystal can convert it to a C function pointer.
    def self._dispatch(widget_id : Int32)
      @@_callbacks[widget_id]?.try(&.call)
    end
  end
end
