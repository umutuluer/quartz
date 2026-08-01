require "../spec_helper"

# Local shorthand around the shared WidgetFactory.
private def create_test_window(title = "Test Window", width = 400, height = 300)
  WidgetFactory.window(title, width, height)
end

describe Quartz::Window do
  describe "type hierarchy" do
    it "inherits from Control" do
      window = create_test_window
      window.should be_a(Quartz::Control)
    end

    it "is a Window" do
      window = create_test_window
      window.should be_a(Quartz::Window)
    end
  end

  describe "#initialize" do
    it "creates a window with default size" do
      window = WidgetFactory.window("Default", 800, 600)
      window.handle.should be > 0
    end

    it "creates a window with custom size" do
      window = WidgetFactory.window("Custom", 1024, 768)
      window.handle.should be > 0
    end

    it "handles zero dimensions" do
      window = WidgetFactory.window("Zero", 0, 0)
      window.handle.should be > 0
    end

    it "each window gets a unique handle" do
      w1 = create_test_window("A")
      w2 = create_test_window("B")
      w3 = create_test_window("C")
      handles = [w1.handle, w2.handle, w3.handle]
      handles.uniq.size.should eq(3)
    end
  end

  describe "#title=" do
    it "sets the title without errors" do
      window = create_test_window("Original")
      window.title = "Updated"
    end

    it "handles empty title" do
      window = create_test_window("X")
      window.title = ""
    end

    it "handles special characters in title" do
      window = create_test_window
      window.title = "Türkçe karakter: ğüşiöç İĞÜŞÖÇ"
    end
  end

  describe "#add_control" do
    it "sets the parent of the added control" do
      window = create_test_window
      label  = WidgetFactory.label("child")

      window.add_control(label)
      label.parent.should eq(window)
    end

    it "can add multiple controls" do
      window = create_test_window
      b1 = WidgetFactory.button("B1", 0, 0, 80, 30)
      b2 = WidgetFactory.button("B2", 90, 0, 80, 30)
      l1 = WidgetFactory.label("L1", 0, 40, 170, 30)

      window.add_control(b1)
      window.add_control(b2)
      window.add_control(l1)

      b1.parent.should eq(window)
      b2.parent.should eq(window)
      l1.parent.should eq(window)
    end

    it "overwrites previous parent" do
      w1 = create_test_window("Window 1")
      w2 = create_test_window("Window 2")
      label = WidgetFactory.label("move me")

      w1.add_control(label)
      label.parent.should eq(w1)

      w2.add_control(label)
      label.parent.should eq(w2)
    end
  end
end
