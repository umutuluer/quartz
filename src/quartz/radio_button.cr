require "./control"

module Quartz
  # A radio button that is mutually exclusive with other radio buttons
  # in the same parent window.
  # (.NET RadioButton)
  #
  # ```
  # rb1 = Quartz::RadioButton.new("Option A", 10, 10, 200, 25)
  # rb2 = Quartz::RadioButton.new("Option B", 10, 40, 200, 25)
  # window.add_control(rb1)
  # window.add_control(rb2)
  # rb1.on_checked_changed { puts "A: #{rb1.checked}" }
  # ```
  class RadioButton < Control
    # Class-level storage so the Crystal GC does not collect callbacks
    # that are passed as C function pointers to the native runtime.
    @@_callbacks = {} of Int32 => ->

    def initialize(text : String, x : Int32, y : Int32, width : Int32, height : Int32, checked : Bool = false)
      handle = LibQuartz.quartz_radiobutton_create(text, x, y, width, height)
      super(handle)
      self.checked = checked if checked
    end

    # Override parent setter: when a parent is assigned and this radio is
    # already checked, uncheck sibling radios in the same parent.
    def parent=(value : Control?)
      super(value)
      if value && checked
        _uncheck_siblings
      end
    end

    # Updates the label displayed next to the radio button.
    def text=(value : String)
      LibQuartz.quartz_widget_set_text(@handle, value)
    end

    # Returns whether the radio button is currently selected.
    # (.NET RadioButton.Checked)
    def checked : Bool
      LibQuartz.quartz_toggle_get_checked(@handle) != 0
    end

    # Sets the selected state. When set to true, all other radio buttons
    # in the same parent window are automatically unchecked.
    # Fires on_checked_changed only when the value actually changes.
    # (.NET RadioButton.Checked)
    def checked=(value : Bool)
      if value
        _uncheck_siblings
      end
      LibQuartz.quartz_toggle_set_checked(@handle, value ? 1 : 0)
    end

    # Enables or disables the radio button.
    # (.NET Control.Enabled)
    def enabled=(value : Bool)
      LibQuartz.quartz_widget_set_enabled(@handle, value ? 1 : 0)
    end

    # Registers a block to be called when the checked state changes.
    # (.NET RadioButton.CheckedChanged)
    #
    # ```
    # radio.on_checked_changed { puts radio.checked }
    # ```
    def on_checked_changed(&block : ->)
      @@_callbacks[@handle] = block
      LibQuartz.quartz_toggle_set_change_callback(@handle, ->RadioButton._dispatch(Int32))
    end

    # Static callback dispatcher — must not capture any local variables
    # so Crystal can convert it to a C function pointer.
    def self._dispatch(widget_id : Int32)
      @@_callbacks[widget_id]?.try(&.call)
    end

    # Unchecks all RadioButton siblings in the same parent window.
    private def _uncheck_siblings
      p = @parent
      return unless p

      if p.responds_to?(:children)
        p.children.each do |child|
          if child.is_a?(RadioButton) && child != self && child.checked
            # Uncheck sibling — native toolkit will fire the callback
            LibQuartz.quartz_toggle_set_checked(child.handle, 0)
          end
        end
      end
    end
  end
end
