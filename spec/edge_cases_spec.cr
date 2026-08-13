require "./spec_helper"
require "../src/quartz/window"
require "../src/quartz/button"
require "../src/quartz/label"
require "../src/quartz/textbox"
require "../src/quartz/listbox"
require "../src/quartz/combo_box"

# The macOS AppKit backend round-trips all text as UTF-8, so these focus on
# not crashing and on exact byte round-trips for the trickiest inputs. All
# native handles are unique per widget, so degenerate dims cannot collide.
describe "Edge cases" do
  describe "Unicode and mixed-script text" do
    it "Label with emoji round-trips" do
      label = WidgetFactory.label("🚀 hello")
      label.text.should eq "🚀 hello"
      label.text = "🚀 world 🌍"
      label.text.should eq "🚀 world 🌍"
    end

    it "Label with RTL Arabic round-trips" do
      label = WidgetFactory.label("مرحبا")
      label.text.should eq "مرحبا"
      label.text = "أهلاً بالعالم"
      label.text.should eq "أهلاً بالعالم"
    end

    it "TextBox with zero-width-joiner emoji round-trips" do
      textbox = WidgetFactory.textbox("👨‍👩‍👧")
      textbox.text.should eq "👨‍👩‍👧"
      textbox.text = "👨‍👩‍👧‍👦"
      textbox.text.should eq "👨‍👩‍👧‍👦"
    end

    it "Window title with mixed scripts round-trips" do
      window = Quartz::Window.new("Hello 世界 🌍", 300, 200)
      window.title.should eq "Hello 世界 🌍"
      window.title = "Türkçe 日本語 العربية 🚀"
      window.title.should eq "Türkçe 日本語 العربية 🚀"
    end
  end

  describe "10k-character strings" do
    it "TextBox set and get a 10_000 character string" do
      textbox = WidgetFactory.textbox
      long = "x" * 10_000
      textbox.text = long
      textbox.text.should eq long
    end

    it "ComboBox item of 10_000 characters round-trips" do
      combo = WidgetFactory.combobox
      long = "z" * 10_000
      combo.add_item(long)
      combo.item_count.should eq 1
      combo.item_text(0).should eq long
    end
  end

  describe "zero and negative dimensions" do
    it "control with width 0 does not crash" do
      button = Quartz::Button.new("zero-w", 0, 0, 0, 30)
      button.handle.should be > 0
    end

    it "control with height -1 does not crash" do
      button = Quartz::Button.new("neg-h", 0, 0, 50, -1)
      button.handle.should be > 0
    end

    it "window 0x0 still produces a valid handle" do
      window = Quartz::Window.new("zero", 0, 0)
      window.handle.should be > 0
      window.width.should eq 0
      window.height.should eq 0
    end

    it "window with negative height does not crash" do
      window = Quartz::Window.new("neg", 1, -5)
      window.handle.should be > 0
    end
  end

  describe "empty strings" do
    it "TextBox with empty text round-trips" do
      textbox = WidgetFactory.textbox("")
      textbox.text.should eq ""
      textbox.text = ""
      textbox.text.should eq ""
    end

    it "ComboBox with empty text round-trips" do
      combo = WidgetFactory.combobox(editable: true)
      combo.text = ""
      combo.text.should eq ""
    end
  end

  describe "ListBox long items" do
    it "10_000 character item is returned by item_text" do
      listbox = WidgetFactory.listbox
      long = "l" * 10_000
      listbox.add_item(long)
      listbox.item_count.should eq 1
      listbox.item_text(0).should eq long
    end
  end
end
