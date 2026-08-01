require "./control"

module Quartz
  # A top-level application window.
  class Window < Control
    # Creates a new window with the given title and client-area size.
    def initialize(title : String, width : Int32 = 800, height : Int32 = 600)
      handle = LibQuartz.quartz_window_create(title, width, height)
      super(handle)
    end

    # Changes the window title.
    def title=(value : String)
      LibQuartz.quartz_window_set_title(@handle, value)
    end

    # Makes the window visible and brings it to the front.
    def show
      LibQuartz.quartz_window_show(@handle)
    end

    # Adds a child control to this window.
    def add_control(control : Control)
      LibQuartz.quartz_widget_set_parent(control.handle, @handle)
      control.parent = self
    end
  end
end
