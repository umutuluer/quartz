require "./lib_quartz"
require "./menu_item"
require "./menu_separator"

module Quartz
  # Shared behaviour for menu containers (`MenuBar`, `ContextMenu`).
  #
  # Both concrete containers keep an ordered list of `MenuItem` /
  # `MenuSeparator` entries and append them to the native menu as they are
  # added, so the native ordering always matches `items`.
  module MenuContainer
    # The ordered list of items added to this menu.
    def items
      @items ||= [] of MenuItem | MenuSeparator
    end

    # Appends a menu item or separator to the native menu and returns
    # `self` to enable method chaining.
    def add_item(item : MenuItem | MenuSeparator)
      items << item
      LibQuartz.quartz_menu_add_item(@handle, item.handle)
      self
    end

    # Appends a visual separator line and returns `self` to enable
    # method chaining.
    def add_separator
      add_item(MenuSeparator.new)
    end
  end
end
