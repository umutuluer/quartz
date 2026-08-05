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

  describe "#title and #title=" do
    it "returns the initial title" do
      window = create_test_window("My Window")
      window.title.should eq("My Window")
    end

    it "sets and returns the updated title" do
      window = create_test_window("Original")
      window.title = "Updated"
      window.title.should eq("Updated")
    end

    it "handles empty title" do
      window = create_test_window("X")
      window.title = ""
      window.title.should eq("")
    end

    it "handles special characters in title" do
      window = create_test_window
      window.title = "Türkçe karakter: ğüşiöç İĞÜŞÖÇ"
      window.title.should eq("Türkçe karakter: ğüşiöç İĞÜŞÖÇ")
    end
  end

  describe "#width and #height" do
    it "returns dimensions passed during initialization" do
      window = WidgetFactory.window("Sized Window", 640, 480)
      window.width.should eq(640)
      window.height.should eq(480)
    end
  end

  describe "#add_control and #children" do
    it "sets the parent of the added control" do
      window = create_test_window
      label = WidgetFactory.label("child")

      window.add_control(label)
      label.parent.should eq(window)
      window.children.should contain(label)
    end

    it "returns the typed control" do
      window = create_test_window
      btn = window.add_control(WidgetFactory.button("Click"))
      btn.should be_a(Quartz::Button)
    end

    it "can add multiple controls and tracks children" do
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
      window.children.size.should eq(3)
    end

    it "overwrites previous parent and updates children collections" do
      w1 = create_test_window("Window 1")
      w2 = create_test_window("Window 2")
      label = WidgetFactory.label("move me")

      w1.add_control(label)
      label.parent.should eq(w1)
      w1.children.should contain(label)

      w2.add_control(label)
      label.parent.should eq(w2)
      w2.children.should contain(label)
      w1.children.should_not contain(label)
    end
  end

  describe "#remove_control" do
    it "removes child control and unsets parent" do
      window = create_test_window
      btn = window.add_control(WidgetFactory.button("Remove me"))

      window.remove_control(btn).should be_true
      btn.parent.should be_nil
      window.children.should_not contain(btn)
    end

    it "returns false when control is not in children" do
      window = create_test_window
      btn = WidgetFactory.button("Unparented")

      window.remove_control(btn).should be_false
    end
  end
end
