require "./lib_quartz"

module Quartz
  # A single clickable entry in a `MenuBar` or `ContextMenu`.
  #
  # A MenuItem is NOT a `Control`: it lives inside a menu rather than a
  # window's children and is identified by its own native handle.
  #
  # ```
  # item = Quartz::MenuItem.new("Quit")
  # item.on_click { puts "Quit!" }
  # ```
  class MenuItem
    # Class-level storage so the Crystal GC does not collect callbacks
    # that are passed as C function pointers to the native runtime.
    @@_callbacks = {} of Int32 => ->

    # The low-level native handle for this menu item.
    getter handle : Int32

    # The label displayed for this menu item.
    getter text : String

    def initialize(text : String)
      @text = text
      @handle = LibQuartz.quartz_menuitem_create(-1, text)
    end

    # Registers a block to be called when the item is clicked.
    # Returns `self` to enable method chaining.
    #
    # ```
    # item.on_click { puts "Clicked!" }
    # ```
    def on_click(&block : ->) : self
      @@_callbacks[@handle] = block
      LibQuartz.quartz_menu_item_set_callback(@handle, ->MenuItem._dispatch(Int32))
      self
    end

    # Static callback dispatcher — must not capture any local variables
    # so Crystal can convert it to a C function pointer.
    def self._dispatch(item_id : Int32)
      @@_callbacks[item_id]?.try(&.call)
    end
  end
end
