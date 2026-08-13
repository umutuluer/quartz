require "../spec_helper"

describe Quartz::TextBox do
  describe "type hierarchy" do
    it "inherits from Control" do
      textbox = WidgetFactory.textbox
      textbox.should be_a(Quartz::Control)
    end

    it "is a TextBox" do
      textbox = WidgetFactory.textbox
      textbox.should be_a(Quartz::TextBox)
    end
  end

  describe "#text getter and setter" do
    it "returns the initial text" do
      textbox = WidgetFactory.textbox("Hello")
      textbox.text.should eq("Hello")
    end

    it "updates text programmatically" do
      textbox = WidgetFactory.textbox("initial")
      textbox.text = "updated"
      textbox.text.should eq("updated")
    end
  end

  describe "properties" do
    it "allows setting max_length" do
      textbox = WidgetFactory.textbox
      textbox.max_length = 50
    end

    it "allows setting read_only" do
      textbox = WidgetFactory.textbox
      textbox.read_only = true
      textbox.read_only = false
    end

    it "allows setting placeholder" do
      textbox = WidgetFactory.textbox
      textbox.placeholder = "Enter text..."
    end

    it "allows setting password_char" do
      textbox = WidgetFactory.textbox
      textbox.password_char = '*'
    end
  end

  describe "._dispatch" do
    it "calls the registered callback" do
      called = false
      captured_id = 0

      textbox = WidgetFactory.textbox
      textbox.on_text_changed do
        called = true
        captured_id = textbox.handle
      end

      Quartz::TextBox._dispatch(textbox.handle)

      called.should be_true
      captured_id.should eq(textbox.handle)
    end

    it "is nil-safe when no callback is registered" do
      textbox = WidgetFactory.textbox
      Quartz::TextBox._dispatch(textbox.handle)
    end

    it "is nil-safe for unknown widget IDs" do
      Quartz::TextBox._dispatch(999_999)
    end

    it "dispatches to the correct textbox among many" do
      t1 = WidgetFactory.textbox
      t2 = WidgetFactory.textbox
      t3 = WidgetFactory.textbox

      results = [] of Int32

      t1.on_text_changed { results << 1 }
      t2.on_text_changed { results << 2 }
      t3.on_text_changed { results << 3 }

      Quartz::TextBox._dispatch(t2.handle)
      results.should eq([2])

      Quartz::TextBox._dispatch(t1.handle)
      results.should eq([2, 1])

      Quartz::TextBox._dispatch(t3.handle)
      results.should eq([2, 1, 3])
    end
  end

  describe "#on_text_changed" do
    it "registers callback without error" do
      textbox = WidgetFactory.textbox
      called = false
      textbox.on_text_changed do
        called = true
      end
    end
  end
end
