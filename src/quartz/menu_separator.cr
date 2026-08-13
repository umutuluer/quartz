require "./lib_quartz"

module Quartz
  # A visual separator drawn between menu items.
  #
  # A MenuSeparator is NOT a `Control`; it is appended to the native menu
  # immediately via `MenuContainer#add_separator`.
  class MenuSeparator
    # The low-level native handle for this separator.
    getter handle : Int32

    def initialize
      @handle = LibQuartz.quartz_menuseparator_create
    end
  end
end
