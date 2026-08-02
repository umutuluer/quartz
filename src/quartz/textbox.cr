require "./control"

module Quartz
  # A single-line text input control, inspired by .NET WinForms TextBox.
  #
  # ```
  # input = Quartz::TextBox.new("", x: 20, y: 20, width: 200, height: 25)
  # input.placeholder = "Enter your name..."
  # input.on_text_changed { puts input.text }
  # ```
  class TextBox < Control
    # Class-level storage so the Crystal GC does not collect callbacks
    # that are passed as C function pointers to the native runtime.
    @@_callbacks = {} of Int32 => ->

    def initialize(text : String = "", x : Int32 = 0, y : Int32 = 0,
                   width : Int32 = 120, height : Int32 = 25)
      handle = LibQuartz.quartz_textbox_create(text, x, y, width, height)
      super(handle)
    end

    # Returns the current text from the native widget.
    # Unlike Label, this reads directly from the native control
    # because the user may have typed text via keyboard.
    def text : String
      ptr = LibQuartz.quartz_textbox_get_text(@handle)
      String.new(ptr)
    end

    # Sets the text programmatically.
    def text=(value : String)
      LibQuartz.quartz_widget_set_text(@handle, value)
    end

    # Sets the maximum number of characters the user can enter.
    # (.NET TextBox.MaxLength)
    def max_length=(value : Int32)
      LibQuartz.quartz_textbox_set_max_length(@handle, value)
    end

    # Sets whether the text box is read-only.
    # (.NET TextBox.ReadOnly)
    def read_only=(value : Bool)
      LibQuartz.quartz_textbox_set_read_only(@handle, value ? 1 : 0)
    end

    # Sets placeholder text shown when the control is empty.
    # (.NET TextBox.PlaceholderText)
    def placeholder=(value : String)
      LibQuartz.quartz_textbox_set_placeholder(@handle, value)
    end

    # Sets the password masking character.
    # (.NET TextBox.PasswordChar)
    def password_char=(value : Char)
      LibQuartz.quartz_textbox_set_password_char(@handle, value.ord.to_u8)
    end

    # Registers a callback for when the text content changes.
    # (.NET TextBox.TextChanged)
    #
    # ```
    # input.on_text_changed { puts "Text: #{input.text}" }
    # ```
    def on_text_changed(&block : ->)
      @@_callbacks[@handle] = block
      LibQuartz.quartz_textbox_set_change_callback(@handle, ->TextBox._dispatch(Int32))
    end

    # Static callback dispatcher — must not capture any local variables
    # so Crystal can convert it to a C function pointer.
    def self._dispatch(widget_id : Int32)
      @@_callbacks[widget_id]?.try(&.call)
    end
  end
end
