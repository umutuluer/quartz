require "../spec_helper"

describe Quartz::ComboBox do
  describe "type hierarchy" do
    it "inherits from Control" do
      combo = WidgetFactory.combobox
      combo.should be_a(Quartz::Control)
    end

    it "is a ComboBox" do
      combo = WidgetFactory.combobox
      combo.should be_a(Quartz::ComboBox)
    end
  end

  describe "#handle" do
    it "returns a positive handle" do
      combo = WidgetFactory.combobox
      combo.handle.should be > 0
    end

    it "each combobox gets a unique handle" do
      c1 = WidgetFactory.combobox
      c2 = WidgetFactory.combobox
      c3 = WidgetFactory.combobox
      handles = [c1.handle, c2.handle, c3.handle]
      handles.uniq.size.should eq(3)
    end
  end

  describe "#add_item" do
    it "adds an item and increases item_count" do
      combo = WidgetFactory.combobox
      combo.add_item("Merhaba")
      combo.item_count.should eq(1)
    end

    it "returns self for method chaining" do
      combo = WidgetFactory.combobox
      result = combo.add_item("Test")
      result.should be(combo)
    end

    it "supports Turkish characters" do
      combo = WidgetFactory.combobox
      combo.add_item("Türkçe karakter: ğüşıöçĞÜŞİÖÇ")
      combo.item_text(0).should eq("Türkçe karakter: ğüşıöçĞÜŞİÖÇ")
    end
  end

  describe "#remove_item" do
    it "removes an item at a valid index" do
      combo = WidgetFactory.combobox
      combo.add_item("A")
      combo.add_item("B")
      combo.add_item("C")
      combo.remove_item(1)
      combo.item_count.should eq(2)
      combo.item_text(0).should eq("A")
      combo.item_text(1).should eq("C")
    end

    it "returns self for method chaining" do
      combo = WidgetFactory.combobox
      combo.add_item("Test")
      result = combo.remove_item(0)
      result.should be(combo)
    end
  end

  describe "#clear" do
    it "removes all items" do
      combo = WidgetFactory.combobox
      combo.add_item("A")
      combo.add_item("B")
      combo.clear
      combo.item_count.should eq(0)
    end

    it "returns self for method chaining" do
      combo = WidgetFactory.combobox
      result = combo.clear
      result.should be(combo)
    end
  end

  describe "#selected_index" do
    it "returns -1 when nothing is selected" do
      combo = WidgetFactory.combobox
      combo.add_item("Test")
      combo.selected_index.should eq(-1)
    end

    it "sets the selected index" do
      combo = WidgetFactory.combobox
      combo.add_item("A")
      combo.add_item("B")
      combo.selected_index = 1
      combo.selected_index.should eq(1)
    end

    it "is a graceful no-op when set to -1" do
      combo = WidgetFactory.combobox
      combo.add_item("A")
      combo.selected_index = 0
      combo.selected_index = -1
      combo.selected_index.should eq(-1)
    end
  end

  describe "#selected_text" do
    it "returns nil when selected_index is -1" do
      combo = WidgetFactory.combobox
      combo.add_item("Test")
      combo.selected_text.should be_nil
    end

    it "returns the selected item text" do
      combo = WidgetFactory.combobox
      combo.add_item("Merhaba")
      combo.add_item("Dünya")
      combo.selected_index = 0
      combo.selected_text.should eq("Merhaba")
    end
  end

  describe "#text" do
    it "returns the selected item text when not editable" do
      combo = WidgetFactory.combobox
      combo.add_item("Kırmızı")
      combo.add_item("Mavi")
      combo.selected_index = 1
      combo.text.should eq("Mavi")
    end

    it "sets text programmatically until a selection overrides it" do
      combo = WidgetFactory.combobox
      combo.add_item("A")
      combo.add_item("B")
      combo.text = "yazı"
      combo.text.should eq("yazı")
      combo.selected_index = 1
      combo.text.should eq("B")
    end
  end

  describe "#item_text" do
    it "returns the text at a valid index" do
      combo = WidgetFactory.combobox
      combo.add_item("İlk")
      combo.item_text(0).should eq("İlk")
    end
  end

  describe "#item_count" do
    it "returns 0 for an empty combobox" do
      combo = WidgetFactory.combobox
      combo.item_count.should eq(0)
    end
  end

  describe "#dropped_down?" do
    it "reports the drop-down state" do
      combo = WidgetFactory.combobox
      combo.dropped_down?.should be_false
    end
  end

  describe "#dropped_down=" do
    it "opens and closes the drop-down without raising" do
      combo = WidgetFactory.combobox
      combo.dropped_down = true
      combo.dropped_down = false
    end
  end

  describe "#initialize" do
    it "constructs with editable: true" do
      combo = WidgetFactory.combobox(editable: true)
      combo.should be_a(Quartz::ComboBox)
    end
  end

  describe "._dispatch_selection" do
    it "calls the registered callback" do
      called = false
      captured_id = 0

      combo = WidgetFactory.combobox
      combo.on_selection_changed do
        called = true
        captured_id = combo.handle
      end

      Quartz::ComboBox._dispatch_selection(combo.handle)

      called.should be_true
      captured_id.should eq(combo.handle)
    end

    it "is nil-safe when no callback is registered" do
      combo = WidgetFactory.combobox
      Quartz::ComboBox._dispatch_selection(combo.handle)
    end

    it "is nil-safe for unknown widget IDs" do
      Quartz::ComboBox._dispatch_selection(999_999)
    end

    it "dispatches to the correct combobox among many" do
      c1 = WidgetFactory.combobox
      c2 = WidgetFactory.combobox
      c3 = WidgetFactory.combobox

      results = [] of Int32

      c1.on_selection_changed { results << 1 }
      c2.on_selection_changed { results << 2 }
      c3.on_selection_changed { results << 3 }

      Quartz::ComboBox._dispatch_selection(c2.handle)
      results.should eq([2])

      Quartz::ComboBox._dispatch_selection(c1.handle)
      results.should eq([2, 1])

      Quartz::ComboBox._dispatch_selection(c3.handle)
      results.should eq([2, 1, 3])
    end
  end

  describe "._dispatch_text" do
    it "calls the registered callback" do
      called = false
      captured_id = 0

      combo = WidgetFactory.combobox
      combo.on_text_changed do
        called = true
        captured_id = combo.handle
      end

      Quartz::ComboBox._dispatch_text(combo.handle)

      called.should be_true
      captured_id.should eq(combo.handle)
    end

    it "is nil-safe when no callback is registered" do
      combo = WidgetFactory.combobox
      Quartz::ComboBox._dispatch_text(combo.handle)
    end

    it "is nil-safe for unknown widget IDs" do
      Quartz::ComboBox._dispatch_text(999_999)
    end
  end

  describe "#on_selection_changed" do
    it "replaces the previous callback" do
      combo = WidgetFactory.combobox
      results = [] of String

      combo.on_selection_changed { results << "first" }
      combo.on_selection_changed { results << "second" }

      Quartz::ComboBox._dispatch_selection(combo.handle)
      results.should eq(["second"])
    end
  end
end
