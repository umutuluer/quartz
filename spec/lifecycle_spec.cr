require "./spec_helper"
require "../src/quartz/window"
require "../src/quartz/button"
require "../src/quartz/label"

# These exercise sequences that unit specs normally treat as "set up once":
# showing a window, re-parenting children, mutating properties after show.
# All are run headless — no real event loop — so "rendering" is verified
# through the native bounds helper (the bounds a layout/lifecycle path
# requested are echoed back deterministically).
describe Quartz::Window do
  describe "lifecycle" do
    it "show can be called multiple times without raising" do
      window = WidgetFactory.window
      window.show.should be(window)
      window.show.should be(window)
    end

    it "controls added after show still get renderable bounds" do
      window = WidgetFactory.window
      window.show
      button = WidgetFactory.button("late")
      window.add_control(button)

      LibQuartz.quartz_widget_set_bounds(button.handle, 10, 10, 100, 30)
      b = BoundsHelper.bounds(button.handle)
      (b[:w] * b[:h]).should be > 0
      b[:x].should eq 10
      b[:y].should eq 10
    end

    it "show with zero dimensions still produces a valid handle" do
      window = Quartz::Window.new("zero", 0, 0)
      window.show
      window.handle.should be > 0
    end

    it "re-parenting one child across three windows tracks the latest parent" do
      w1 = Quartz::Window.new("w1")
      w2 = Quartz::Window.new("w2")
      w3 = Quartz::Window.new("w3")
      label = WidgetFactory.label("mover")

      w1.add_control(label)
      label.parent.should eq(w1)

      w2.add_control(label)
      label.parent.should eq(w2)
      w1.children.should_not contain(label)

      w3.add_control(label)
      label.parent.should eq(w3)
      w2.children.should_not contain(label)
      w3.children.should contain(label)
    end

    it "handle stays stable across repeated show calls" do
      window = WidgetFactory.window
      first = window.handle
      window.show
      window.show
      window.handle.should eq(first)
    end
  end

  describe "after operations, widgets stay queryable" do
    it "title set after show returns the new value" do
      window = WidgetFactory.window("before")
      window.show
      window.title = "after"
      window.title.should eq("after")
    end

    it "children reflect the latest window after re-parenting" do
      w1 = Quartz::Window.new("src")
      w2 = Quartz::Window.new("dst")
      label = WidgetFactory.label("move")
      w1.add_control(label)
      w2.add_control(label)

      label.parent.should eq(w2)
      w2.children.should contain(label)
      w1.children.should_not contain(label)
    end

    it "children of a shown window are still queryable" do
      window = WidgetFactory.window
      window.show
      label = window.add_control(WidgetFactory.label("child"))
      window.children.should contain(label)
      label.parent.should eq(window)
    end

    it "control bounds stay queryable after re-parent and repositioning" do
      w1 = Quartz::Window.new("a")
      w2 = Quartz::Window.new("b")
      label = WidgetFactory.label("repos")
      w1.add_control(label)
      w2.add_control(label)

      LibQuartz.quartz_widget_set_bounds(label.handle, 20, 40, 120, 25)
      b = BoundsHelper.bounds(label.handle)
      b[:x].should eq 20
      b[:y].should eq 40
      b[:w].should eq 120
      b[:h].should eq 25
    end

    it "removing a control after show is safe" do
      window = WidgetFactory.window
      window.show
      button = window.add_control(WidgetFactory.button("gone"))
      window.remove_control(button).should be_true
      button.parent.should be_nil
      window.children.should_not contain(button)
    end
  end
end
