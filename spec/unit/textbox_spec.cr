require "../spec_helper"

private def create_test_textbox(text = "Test", x = 0, y = 0, width = 120, height = 25)
  WidgetFactory.textbox(text, x, y, width, height)
end

describe Quartz::TextBox do
  describe "type hierarchy" do
    it "inherits from Control" do
      textbox = create_test_textbox
      textbox.should be_a(Quartz::Control)
    end

    it "is a TextBox" do
      textbox = create_test_textbox
      textbox.should be_a(Quartz::TextBox)
    end
  end

  describe "#text getter and setter" do
    it "returns the initial text" do
      textbox = create_test_textbox("Hello")
      textbox.text.should eq("Hello")
    end

    it "updates text programmatically" do
      textbox = create_test_textbox("initial")
      textbox.text = "updated"
      textbox.text.should eq("updated")
    end
  end

  describe "properties" do
    it "allows setting max_length" do
      textbox = create_test_textbox
      textbox.max_length = 50
    end

    it "allows setting read_only" do
      textbox = create_test_textbox
      textbox.read_only = true
      textbox.read_only = false
    end

    it "allows setting placeholder" do
      textbox = create_test_textbox
      textbox.placeholder = "Enter text..."
    end

    it "allows setting password_char" do
      textbox = create_test_textbox
      textbox.password_char = '*'
    end
  end

  describe "#on_text_changed" do
    it "registers callback without error" do
      textbox = create_test_textbox
      called = false
      textbox.on_text_changed do
        called = true
      end
    end
  end
end
