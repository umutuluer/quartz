require "./control"

module Quartz
  # A read-only text label.
  class Label < Control
    # Crystal-side text cache so we can read back without a round-trip
    # through the ObjC bridge.
    @_text : String

    def initialize(text : String, x : Int32, y : Int32, width : Int32, height : Int32)
      @_text = text
      handle = LibQuartz.quartz_label_create(text, x, y, width, height)
      super(handle)
    end

    # Returns the current label text.
    def text : String
      @_text
    end

    # Updates the label text.
    def text=(value : String)
      @_text = value
      LibQuartz.quartz_widget_set_text(@handle, value)
    end
  end
end
