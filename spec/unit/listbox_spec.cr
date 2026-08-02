require "../spec_helper"

# Local shorthand around the shared WidgetFactory.
private def create_test_listbox(x = 0, y = 0, width = 150, height = 100)
  WidgetFactory.listbox(x, y, width, height)
end

describe Quartz::ListBox do
  describe "type hierarchy" do
    it "inherits from Control" do
      listbox = create_test_listbox
      listbox.should be_a(Quartz::Control)
    end

    it "is a ListBox" do
      listbox = create_test_listbox
      listbox.should be_a(Quartz::ListBox)
    end
  end

  describe "#handle" do
    it "returns a positive handle" do
      listbox = create_test_listbox
      listbox.handle.should be > 0
    end

    it "each listbox gets a unique handle" do
      l1 = create_test_listbox
      l2 = create_test_listbox
      l3 = create_test_listbox
      handles = [l1.handle, l2.handle, l3.handle]
      handles.uniq.size.should eq(3)
    end
  end

  describe "#add_item" do
    it "adds an item and increases item_count" do
      listbox = create_test_listbox
      listbox.add_item("Merhaba")
      listbox.item_count.should eq(1)
    end

    it "adds multiple items" do
      listbox = create_test_listbox
      listbox.add_item("Öğe 1")
      listbox.add_item("Öğe 2")
      listbox.add_item("Öğe 3")
      listbox.item_count.should eq(3)
    end

    it "returns self for method chaining" do
      listbox = create_test_listbox
      result = listbox.add_item("Test")
      result.should be(listbox)
    end

    it "supports Turkish characters" do
      listbox = create_test_listbox
      listbox.add_item("Türkçe karakter: ğüşıöçĞÜŞİÖÇ")
      listbox.item_text(0).should eq("Türkçe karakter: ğüşıöçĞÜŞİÖÇ")
    end

    it "supports empty string" do
      listbox = create_test_listbox
      listbox.add_item("")
      listbox.item_text(0).should eq("")
    end
  end

  describe "#remove_item" do
    it "removes an item at a valid index" do
      listbox = create_test_listbox
      listbox.add_item("A")
      listbox.add_item("B")
      listbox.add_item("C")
      listbox.remove_item(1)
      listbox.item_count.should eq(2)
      listbox.item_text(0).should eq("A")
      listbox.item_text(1).should eq("C")
    end

    it "returns self for method chaining" do
      listbox = create_test_listbox
      listbox.add_item("Test")
      result = listbox.remove_item(0)
      result.should be(listbox)
    end
  end

  describe "#clear" do
    it "removes all items" do
      listbox = create_test_listbox
      listbox.add_item("A")
      listbox.add_item("B")
      listbox.clear
      listbox.item_count.should eq(0)
    end

    it "is safe to call on empty listbox" do
      listbox = create_test_listbox
      listbox.clear
      listbox.item_count.should eq(0)
    end

    it "returns self for method chaining" do
      listbox = create_test_listbox
      result = listbox.clear
      result.should be(listbox)
    end
  end

  describe "#selected_index" do
    it "returns -1 when nothing is selected" do
      listbox = create_test_listbox
      listbox.add_item("Test")
      listbox.selected_index.should eq(-1)
    end

    it "sets the selected index" do
      listbox = create_test_listbox
      listbox.add_item("A")
      listbox.add_item("B")
      listbox.selected_index = 1
      listbox.selected_index.should eq(1)
    end

    it "clears selection with -1" do
      listbox = create_test_listbox
      listbox.add_item("A")
      listbox.selected_index = 0
      listbox.selected_index = -1
      listbox.selected_index.should eq(-1)
    end
  end

  describe "#selected_text" do
    it "returns nil when nothing is selected" do
      listbox = create_test_listbox
      listbox.add_item("Test")
      listbox.selected_text.should be_nil
    end

    it "returns the selected item text" do
      listbox = create_test_listbox
      listbox.add_item("Merhaba")
      listbox.add_item("Dünya")
      listbox.selected_index = 0
      listbox.selected_text.should eq("Merhaba")
    end
  end

  describe "#item_count" do
    it "returns 0 for an empty listbox" do
      listbox = create_test_listbox
      listbox.item_count.should eq(0)
    end

    it "returns the correct count after adding items" do
      listbox = create_test_listbox
      listbox.add_item("A")
      listbox.add_item("B")
      listbox.item_count.should eq(2)
    end
  end

  describe "#item_text" do
    it "returns the text at a valid index" do
      listbox = create_test_listbox
      listbox.add_item("İlk")
      listbox.item_text(0).should eq("İlk")
    end
  end

  describe "._dispatch" do
    it "calls the registered callback" do
      called = false
      captured_id = 0

      listbox = create_test_listbox
      listbox.on_selection_changed do
        called = true
        captured_id = listbox.handle
      end

      Quartz::ListBox._dispatch(listbox.handle)

      called.should be_true
      captured_id.should eq(listbox.handle)
    end

    it "is nil-safe when no callback is registered" do
      listbox = create_test_listbox
      Quartz::ListBox._dispatch(listbox.handle)
    end

    it "is nil-safe for unknown widget IDs" do
      Quartz::ListBox._dispatch(999_999)
    end

    it "dispatches to the correct listbox among many" do
      l1 = create_test_listbox
      l2 = create_test_listbox
      l3 = create_test_listbox

      results = [] of Int32

      l1.on_selection_changed { results << 1 }
      l2.on_selection_changed { results << 2 }
      l3.on_selection_changed { results << 3 }

      Quartz::ListBox._dispatch(l2.handle)
      results.should eq([2])

      Quartz::ListBox._dispatch(l1.handle)
      results.should eq([2, 1])

      Quartz::ListBox._dispatch(l3.handle)
      results.should eq([2, 1, 3])
    end
  end

  describe "#on_selection_changed" do
    it "replaces the previous callback" do
      listbox = create_test_listbox
      results = [] of String

      listbox.on_selection_changed { results << "first" }
      listbox.on_selection_changed { results << "second" }

      Quartz::ListBox._dispatch(listbox.handle)
      results.should eq(["second"])
    end
  end
end
