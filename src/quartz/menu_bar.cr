require "./lib_quartz"
require "./menu_container"
require "./menu_item"
require "./menu_separator"

module Quartz
  # A top-level menu bar, attached to a window via `Window#menu_bar=`.
  #
  # On macOS the menubar is app-global (`[NSApp setMainMenu:]`), so with
  # multiple windows the last `window.menu_bar=` assignment wins.
  #
  # ```
  # bar = Quartz::MenuBar.new
  # bar.add_item("Quit") { Quartz::Application.exit }
  # window.menu_bar = bar
  # ```
  class MenuBar
    include MenuContainer

    # The low-level native handle for this menu bar.
    getter handle : Int32

    def initialize
      @handle = LibQuartz.quartz_menubar_create
    end

    # Convenience helper: creates a clickable item with the given label,
    # registers the block as its click callback, and appends it to this
    # menu bar. Returns `self` to enable method chaining.
    def add_item(text : String, &block : ->) : self
      item = MenuItem.new(text)
      item.on_click(&block)
      add_item(item)
    end
  end
end
