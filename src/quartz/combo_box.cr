require "./control"

module Quartz
  # A drop-down list with an optional editable text field, inspired by
  # .NET WinForms ComboBox.
  #
  # ```
  # combo = Quartz::ComboBox.new(x: 20, y: 60, width: 200, height: 25)
  # combo.add_item("Öğe 1")
  # combo.add_item("Öğe 2")
  # combo.on_selection_changed { puts combo.selected_text }
  # ```
  class ComboBox < Control
    # Class-level storage so the Crystal GC does not collect callbacks
    # that are passed as C function pointers to the native runtime.
    # Selection and text callbacks are pinned in separate hashes.
    @@_selection_callbacks = {} of Int32 => ->
    @@_text_callbacks = {} of Int32 => ->

    def initialize(x : Int32 = 0, y : Int32 = 0,
                   width : Int32 = 150, height : Int32 = 24, editable : Bool = false)
      handle = LibQuartz.quartz_combobox_create(x, y, width, height, editable ? 1 : 0)
      super(handle)
    end

    # Adds an item to the end of the drop-down list.
    # (.NET ComboBox.Items.Add)
    #
    # ```
    # combo.add_item("Yeni öğe")
    # ```
    def add_item(text : String) : self
      LibQuartz.quartz_combobox_add_item(@handle, text)
      self
    end

    # Removes the item at the given index.
    # (.NET ComboBox.Items.RemoveAt)
    #
    # ```
    # combo.remove_item(2)
    # ```
    def remove_item(index : Int32) : self
      LibQuartz.quartz_combobox_remove_item(@handle, index)
      self
    end

    # Removes all items from the drop-down list.
    # (.NET ComboBox.Items.Clear)
    #
    # ```
    # combo.clear
    # ```
    def clear : self
      LibQuartz.quartz_combobox_clear(@handle)
      self
    end

    # Returns the zero-based index of the currently selected item.
    # Returns -1 if no item is selected.
    # (.NET ComboBox.SelectedIndex)
    def selected_index : Int32
      LibQuartz.quartz_combobox_get_selected_index(@handle)
    end

    # Sets the selected item by index.
    # Pass -1 to clear the selection.
    # (.NET ComboBox.SelectedIndex)
    def selected_index=(value : Int32) : Int32
      LibQuartz.quartz_combobox_set_selected_index(@handle, value)
      value
    end

    # Returns the text of the currently selected item, or nil if nothing
    # is selected. Unlike ListBox there is no dedicated native getter, so
    # the text is derived from the selected index.
    # (.NET ComboBox.SelectedItem via ToString)
    #
    # ```
    # if text = combo.selected_text
    #   puts "Selected: #{text}"
    # end
    # ```
    def selected_text : String?
      idx = LibQuartz.quartz_combobox_get_selected_index(@handle)
      return if idx < 0
      ptr = LibQuartz.quartz_combobox_get_item_text(@handle, idx)
      String.new(ptr)
    end

    # Returns the total number of items in the drop-down list.
    # (.NET ComboBox.Items.Count)
    def item_count : Int32
      LibQuartz.quartz_combobox_get_item_count(@handle)
    end

    # Returns the text of the item at the given index.
    # (.NET ComboBox.Items[index])
    #
    # ```
    # puts combo.item_text(0) # => "İlk öğe"
    # ```
    def item_text(index : Int32) : String
      ptr = LibQuartz.quartz_combobox_get_item_text(@handle, index)
      String.new(ptr)
    end

    # Returns the current text shown in the combo box. On a read-only
    # combo box this is the selected item's text; on an editable one it
    # reflects whatever the user typed.
    # (.NET ComboBox.Text)
    def text : String
      ptr = LibQuartz.quartz_combobox_get_text(@handle)
      String.new(ptr)
    end

    # Sets the current text programmatically.
    # (.NET ComboBox.Text)
    def text=(value : String)
      LibQuartz.quartz_combobox_set_text(@handle, value)
    end

    # Returns whether the drop-down list is currently open. Note that the
    # macOS AppKit and GTK 3 backends expose no public query API, so this
    # is reported as always false there.
    # (.NET ComboBox.DroppedDown)
    def dropped_down? : Bool
      LibQuartz.quartz_combobox_get_dropped_down(@handle) != 0
    end

    # Opens or closes the drop-down list.
    # (.NET ComboBox.DroppedDown)
    def dropped_down=(value : Bool)
      LibQuartz.quartz_combobox_set_dropped_down(@handle, value ? 1 : 0)
    end

    # Registers a callback for when the selected item changes.
    # (.NET ComboBox.SelectedIndexChanged)
    #
    # ```
    # combo.on_selection_changed do
    #   puts "Selected: #{combo.selected_text}"
    # end
    # ```
    def on_selection_changed(&block : ->)
      @@_selection_callbacks[@handle] = block
      LibQuartz.quartz_combobox_set_selection_callback(@handle, ->ComboBox._dispatch_selection(Int32))
    end

    # Registers a callback for when the edit text changes.
    # (.NET ComboBox.TextChanged)
    #
    # ```
    # combo.on_text_changed { puts combo.text }
    # ```
    def on_text_changed(&block : ->)
      @@_text_callbacks[@handle] = block
      LibQuartz.quartz_combobox_set_text_callback(@handle, ->ComboBox._dispatch_text(Int32))
    end

    # Static callback dispatchers — must not capture any local variables
    # so Crystal can convert them to C function pointers.
    def self._dispatch_selection(widget_id : Int32)
      @@_selection_callbacks[widget_id]?.try(&.call)
    end

    def self._dispatch_text(widget_id : Int32)
      @@_text_callbacks[widget_id]?.try(&.call)
    end
  end
end
