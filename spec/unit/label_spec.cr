require "../spec_helper"

# Local shorthand around the shared WidgetFactory.
private def create_test_label(text = "Test", x = 0, y = 0, width = 100, height = 30)
  WidgetFactory.label(text, x, y, width, height)
end

describe Quartz::Label do
  describe "type hierarchy" do
    it "inherits from Control" do
      label = create_test_label
      label.should be_a(Quartz::Control)
    end

    it "is a Label" do
      label = create_test_label
      label.should be_a(Quartz::Label)
    end
  end

  describe "#text getter" do
    it "returns the text passed to the constructor" do
      label = create_test_label("Merhaba Dünya!")
      label.text.should eq("Merhaba Dünya!")
    end

    it "returns the cached text without C round-trip" do
      label = create_test_label("cached")
      # Read twice to confirm caching is consistent
      label.text.should eq("cached")
      label.text.should eq("cached")
    end

    it "handles empty strings" do
      label = create_test_label("")
      label.text.should eq("")
    end

    it "handles special characters" do
      label = create_test_label("line1\nline2\t tab → ✓")
      label.text.should eq("line1\nline2\t tab → ✓")
    end

    it "handles very long strings" do
      long = "A" * 10_000
      label = create_test_label(long)
      label.text.size.should eq(10_000)
      label.text.should eq(long)
    end
  end

  describe "#text= setter" do
    it "updates the cached text" do
      label = create_test_label("original")
      label.text.should eq("original")

      label.text = "updated"
      label.text.should eq("updated")
    end

    it "can be set multiple times" do
      label = create_test_label("first")
      label.text = "second"
      label.text = "third"
      label.text.should eq("third")
    end
  end

  describe "#handle" do
    it "returns a positive handle" do
      label = create_test_label
      label.handle.should be > 0
    end
  end
end
