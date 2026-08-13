require "./control"
require "./menu_bar"

module Quartz
  # A top-level application window.
  #
  # Example:
  # ```
  # window = Quartz::Window.new("My App", 800, 600)
  # button = window.add_control(Quartz::Button.new("OK", 10, 10, 80, 30))
  # window.show
  # ```
  class Window < Control
    # The current title of the window.
    getter title : String

    # Client-area width in pixels.
    getter width : Int32

    # Client-area height in pixels.
    getter height : Int32

    # List of child controls contained within this window.
    getter children : Array(Control)

    # Creates a new window with the given title and client-area size.
    def initialize(title : String, width : Int32 = 800, height : Int32 = 600)
      @title = title
      @width = width
      @height = height
      @children = [] of Control

      handle = LibQuartz.quartz_window_create(title, width, height)
      super(handle)
    end

    # Changes the window title.
    def title=(value : String)
      @title = value
      LibQuartz.quartz_window_set_title(@handle, value)
    end

    # Makes the window visible and brings it to the front.
    # Returns `self` to enable method chaining.
    def show : self
      LibQuartz.quartz_window_show(@handle)
      self
    end

    # Adds a child control to this window and returns the control.
    #
    # Retains a reference in `@children` to prevent premature GC collection
    # and automatically removes the control from any previous window parent.
    def add_control(control : T) : T forall T
      if old_parent = control.parent
        if old_parent.is_a?(Window)
          old_parent.@children.delete(control)
        end
      end

      LibQuartz.quartz_widget_set_parent(control.handle, @handle)
      control.parent = self
      @children << control unless @children.includes?(control)
      control
    end

    # Removes a child control from this window.
    def remove_control(control : Control) : Bool
      if @children.delete(control)
        control.parent = nil
        true
      else
        false
      end
    end

    # Attaches a menu bar to this window. Returns `self` to enable
    # method chaining.
    #
    # On macOS the menubar is app-global — with multiple windows the
    # last assignment wins.
    def menu_bar=(bar : MenuBar) : self
      LibQuartz.quartz_window_set_menubar(@handle, bar.handle)
      self
    end
  end
end
