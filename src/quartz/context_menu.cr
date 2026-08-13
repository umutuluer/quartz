require "./lib_quartz"
require "./menu_container"
require "./menu_item"
require "./menu_separator"

module Quartz
  # A right-click (context) menu, attached to any control via
  # `Control#context_menu=`.
  #
  # ```
  # menu = Quartz::ContextMenu.new
  # menu.add_item("Copy") { puts "Copy" }
  # textbox.context_menu = menu
  # ```
  class ContextMenu
    include MenuContainer

    # The low-level native handle for this context menu.
    getter handle : Int32

    def initialize
      @handle = LibQuartz.quartz_contextmenu_create
    end

    # Convenience helper: creates a clickable item with the given label,
    # registers the block as its click callback, and appends it to this
    # context menu. Returns `self` to enable method chaining.
    def add_item(text : String, &block : ->) : self
      item = MenuItem.new(text)
      item.on_click(&block)
      add_item(item)
    end
  end
end
