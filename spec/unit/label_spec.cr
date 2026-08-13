require "../spec_helper"

describe Quartz::Label do
  describe "type hierarchy" do
    it "inherits from Control" do
      label = WidgetFactory.label
      label.should be_a(Quartz::Control)
    end

    it "is a Label" do
      label = WidgetFactory.label
      label.should be_a(Quartz::Label)
    end
  end

  describe "#text getter" do
    it "returns the text passed to the constructor" do
      label = WidgetFactory.label("Merhaba Dünya!")
      label.text.should eq("Merhaba Dünya!")
    end

    it "returns the cached text without C round-trip" do
      label = WidgetFactory.label("cached")
      # Read twice to confirm caching is consistent
      label.text.should eq("cached")
      label.text.should eq("cached")
    end

    it "handles empty strings" do
      label = WidgetFactory.label("")
      label.text.should eq("")
    end

    it "handles special characters" do
      label = WidgetFactory.label("line1\nline2\t tab → ✓")
      label.text.should eq("line1\nline2\t tab → ✓")
    end

    it "handles very long strings" do
      long = "A" * 10_000
      label = WidgetFactory.label(long)
      label.text.size.should eq(10_000)
      label.text.should eq(long)
    end
  end

  describe "#text= setter" do
    it "updates the cached text" do
      label = WidgetFactory.label("original")
      label.text.should eq("original")

      label.text = "updated"
      label.text.should eq("updated")
    end

    it "can be set multiple times" do
      label = WidgetFactory.label("first")
      label.text = "second"
      label.text = "third"
      label.text.should eq("third")
    end
  end

  describe "#handle" do
    it "returns a positive handle" do
      label = WidgetFactory.label
      label.handle.should be > 0
    end
  end
end
