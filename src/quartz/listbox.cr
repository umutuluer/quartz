require "./control"

module Quartz
  # A scrollable list of selectable items, inspired by .NET WinForms ListBox.
  #
  # ```
  # listbox = Quartz::ListBox.new(x: 20, y: 60, width: 300, height: 200)
  # listbox.add_item("Öğe 1")
  # listbox.add_item("Öğe 2")
  # listbox.on_selection_changed { puts listbox.selected_text }
  # ```
  class ListBox < Control
    # Class-level storage so the Crystal GC does not collect callbacks
    # that are passed as C function pointers to the native runtime.
    @@_selection_callbacks = {} of Int32 => ->

    def initialize(x : Int32 = 0, y : Int32 = 0,
                   width : Int32 = 150, height : Int32 = 100)
      handle = LibQuartz.quartz_listbox_create(x, y, width, height)
      super(handle)
    end

    # Adds an item to the end of the list.
    # (.NET ListBox.Items.Add)
    #
    # ```
    # listbox.add_item("Yeni öğe")
    # ```
    def add_item(text : String) : self
      LibQuartz.quartz_listbox_add_item(@handle, text)
      self
    end

    # Removes the item at the given index.
    # (.NET ListBox.Items.RemoveAt)
    #
    # ```
    # listbox.remove_item(2)
    # ```
    def remove_item(index : Int32) : self
      LibQuartz.quartz_listbox_remove_item(@handle, index)
      self
    end

    # Removes all items from the list.
    # (.NET ListBox.Items.Clear)
    #
    # ```
    # listbox.clear
    # ```
    def clear : self
      LibQuartz.quartz_listbox_clear(@handle)
      self
    end

    # Returns the zero-based index of the currently selected item.
    # Returns -1 if no item is selected.
    # (.NET ListBox.SelectedIndex)
    def selected_index : Int32
      LibQuartz.quartz_listbox_get_selected_index(@handle)
    end

    # Sets the selected item by index.
    # Pass -1 to clear the selection.
    # (.NET ListBox.SelectedIndex)
    def selected_index=(value : Int32)
      LibQuartz.quartz_listbox_set_selected_index(@handle, value)
    end

    # Returns the text of the currently selected item, or nil if nothing is selected.
    # (.NET ListBox.SelectedItem via ToString)
    #
    # ```
    # if text = listbox.selected_text
    #   puts "Selected: #{text}"
    # end
    # ```
    def selected_text : String?
      ptr = LibQuartz.quartz_listbox_get_selected_text(@handle)
      ptr.null? ? nil : String.new(ptr)
    end

    # Returns the total number of items in the list.
    # (.NET ListBox.Items.Count)
    def item_count : Int32
      LibQuartz.quartz_listbox_get_item_count(@handle)
    end

    # Returns the text of the item at the given index.
    # (.NET ListBox.Items[index])
    #
    # ```
    # puts listbox.item_text(0) # => "İlk öğe"
    # ```
    def item_text(index : Int32) : String
      ptr = LibQuartz.quartz_listbox_get_item_text(@handle, index)
      String.new(ptr)
    end

    # Registers a callback for when the selected item changes.
    # (.NET ListBox.SelectedIndexChanged)
    #
    # ```
    # listbox.on_selection_changed do
    #   puts "Selected: #{listbox.selected_text}"
    # end
    # ```
    def on_selection_changed(&block : ->)
      @@_selection_callbacks[@handle] = block
      LibQuartz.quartz_listbox_set_selection_callback(@handle, ->ListBox._dispatch(Int32))
    end

    # Static callback dispatcher — must not capture any local variables
    # so Crystal can convert it to a C function pointer.
    def self._dispatch(widget_id : Int32)
      @@_selection_callbacks[widget_id]?.try(&.call)
    end
  end
end
