require "./control"
require "./window"
require "./lib_quartz"

module Quartz
  # A layout manager that stacks child controls vertically (a column)
  # or horizontally (a row).
  #
  # `StackLayout` is a pure Crystal coordinator — it is not a `Control`,
  # has no native handle, and does not touch the `Window#add_control`
  # hierarchy. It only repositions the controls registered with `add`
  # by computing the layout arithmetic in Crystal and assigning the
  # resulting bounds through `LibQuartz.quartz_widget_set_bounds`.
  #
  # ```
  # layout = Quartz::StackLayout.new(padding: 8, spacing: 4)
  # layout.add(button, 80, 30).add(label, 360, 30)
  # layout.relayout
  # ```
  class StackLayout
    enum Orientation
      Horizontal
      Vertical
    end

    @entries : Array({control: Control, w: Int32, h: Int32})

    getter orientation : Orientation
    getter padding : Int32
    getter spacing : Int32

    def initialize(@orientation : Orientation = Orientation::Vertical,
                   @padding : Int32 = 0,
                   @spacing : Int32 = 0)
      @entries = [] of {control: Control, w: Int32, h: Int32}
    end

    # Registers a child with its layout width/height.
    #
    # The control is expected to have been attached to a window via
    # `Window#add_control`. No relayout is triggered on add — call
    # `relayout` manually when you are ready.
    def add(control : Control, width : Int32, height : Int32) : self
      @entries << {control: control, w: width, h: height}
      self
    end

    # Removes a child and relayouts the remaining ones.
    def remove(control : Control) : self
      @entries.reject! { |e| e[:control] == control }
      relayout
      self
    end

    # Removes all children without relayout.
    def clear : self
      @entries.clear
      self
    end

    # Returns the number of registered children.
    def size : Int32
      @entries.size
    end

    # Repositions all children according to the layout rules.
    #
    # Vertical: children stacked top-to-bottom, each stretched to
    #   `parent_width - 2 * padding`.
    # Horizontal: children laid out left-to-right at their given width,
    #   stretched to `parent_height - 2 * padding`.
    #
    # Manual trigger: there is no automatic relayout on window resize
    # yet, so call this again whenever the window size changes.
    def relayout : self
      parent = parent_window
      return self unless parent

      case @orientation
      when Orientation::Vertical
        layout_vertical(parent)
      when Orientation::Horizontal
        layout_horizontal(parent)
      end
      self
    end

    private def parent_window : Window?
      return if @entries.empty?
      @entries[0][:control].parent.as?(Window)
    end

    private def layout_vertical(parent : Window)
      x = @padding
      y = @padding
      width = parent.width - 2 * @padding

      @entries.each do |entry|
        LibQuartz.quartz_widget_set_bounds(
          entry[:control].handle, x, y, width, entry[:h]
        )
        y += entry[:h] + @spacing
      end
    end

    private def layout_horizontal(parent : Window)
      x = @padding
      y = @padding
      height = parent.height - 2 * @padding

      @entries.each do |entry|
        LibQuartz.quartz_widget_set_bounds(
          entry[:control].handle, x, y, entry[:w], height
        )
        x += entry[:w] + @spacing
      end
    end
  end
end
