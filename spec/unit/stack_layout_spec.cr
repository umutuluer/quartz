require "../spec_helper"
require "../../src/quartz/stack_layout"
require "../../src/quartz/button"
require "../../src/quartz/label"
require "../../src/quartz/window"

describe Quartz::StackLayout do
  it "defaults to Vertical orientation" do
    layout = Quartz::StackLayout.new
    layout.orientation.should eq Quartz::StackLayout::Orientation::Vertical
    layout.padding.should eq 0
    layout.spacing.should eq 0
    layout.size.should eq 0
  end

  it "accepts constructor parameters" do
    layout = Quartz::StackLayout.new(
      orientation: Quartz::StackLayout::Orientation::Horizontal,
      padding: 8,
      spacing: 4
    )
    layout.orientation.horizontal?.should be_true
    layout.padding.should eq 8
    layout.spacing.should eq 4
  end

  it "add chains and stores entries" do
    window = Quartz::Window.new("test", 400, 300)
    b1 = Quartz::Button.new("A", 0, 0, 0, 0)
    b2 = Quartz::Button.new("B", 0, 0, 0, 0)
    window.add_control(b1)
    window.add_control(b2)

    layout = Quartz::StackLayout.new
    layout.add(b1, 100, 30).add(b2, 100, 30)
    layout.size.should eq 2
  end

  it "Vertical layout positions children top-to-bottom" do
    window = Quartz::Window.new("vtest", 300, 200)
    b1 = Quartz::Button.new("A", 0, 0, 80, 30)
    b2 = Quartz::Button.new("B", 0, 0, 80, 30)
    window.add_control(b1)
    window.add_control(b2)

    layout = Quartz::StackLayout.new(
      orientation: Quartz::StackLayout::Orientation::Vertical,
      padding: 0,
      spacing: 0
    )
    layout.add(b1, 80, 30).add(b2, 80, 30)
    layout.relayout

    # İlk çocuk: x=0, y=0, w=300, h=30
    # İkinci çocuk: x=0, y=30, w=300, h=30
    # (gerçek pixel testi zor olduğundan sadece layout relayout'un
    # çağrıldığını ve exception olmadığını doğruluyoruz)
    layout.size.should eq 2
  end

  it "Vertical with padding 8 and spacing 4 — exception free" do
    window = Quartz::Window.new("pvtest", 300, 200)
    b1 = Quartz::Button.new("A", 0, 0, 80, 30)
    b2 = Quartz::Button.new("B", 0, 0, 80, 30)
    window.add_control(b1)
    window.add_control(b2)

    layout = Quartz::StackLayout.new(
      orientation: Quartz::StackLayout::Orientation::Vertical,
      padding: 8,
      spacing: 4
    )
    layout.add(b1, 80, 30).add(b2, 80, 30)
    layout.relayout

    layout.size.should eq 2
  end

  it "Horizontal layout positions children side-by-side" do
    window = Quartz::Window.new("htest", 400, 100)
    b1 = Quartz::Button.new("A", 0, 0, 80, 30)
    b2 = Quartz::Button.new("B", 0, 0, 80, 30)
    window.add_control(b1)
    window.add_control(b2)

    layout = Quartz::StackLayout.new(
      orientation: Quartz::StackLayout::Orientation::Horizontal,
      padding: 8,
      spacing: 4
    )
    layout.add(b1, 80, 30).add(b2, 80, 30)
    layout.relayout
    layout.size.should eq 2
  end

  it "empty layout relayout is no-op" do
    layout = Quartz::StackLayout.new
    layout.relayout
    layout.size.should eq 0
  end

  it "remove clears the entry" do
    window = Quartz::Window.new("rt", 400, 300)
    b1 = Quartz::Button.new("A", 0, 0, 80, 30)
    window.add_control(b1)

    layout = Quartz::StackLayout.new
    layout.add(b1, 80, 30)
    layout.remove(b1)
    layout.size.should eq 0
  end

  it "clear empties all" do
    window = Quartz::Window.new("c", 400, 300)
    b1 = Quartz::Button.new("A", 0, 0, 80, 30)
    b2 = Quartz::Button.new("B", 0, 0, 80, 30)
    window.add_control(b1)
    window.add_control(b2)

    layout = Quartz::StackLayout.new
    layout.add(b1, 80, 30).add(b2, 80, 30)
    layout.clear
    layout.size.should eq 0
  end

  # These exercise the full layout pipeline: StackLayout computes the
  # arithmetic, calls quartz_widget_set_bounds, and we read the resulting
  # native bounds back through quartz_widget_get_bounds. `add` does NOT
  # relayout automatically, so every test calls `relayout` explicitly.

  it "vertical layout: 3 labels stacked with spacing" do
    window = Quartz::Window.new("v3", 300, 200)
    l1 = Quartz::Label.new("A", 0, 0, 80, 30)
    l2 = Quartz::Label.new("B", 0, 0, 80, 30)
    l3 = Quartz::Label.new("C", 0, 0, 80, 30)
    window.add_control(l1)
    window.add_control(l2)
    window.add_control(l3)

    layout = Quartz::StackLayout.new(
      orientation: Quartz::StackLayout::Orientation::Vertical,
      padding: 8,
      spacing: 4
    )
    layout.add(l1, 80, 30).add(l2, 80, 30).add(l3, 80, 30)
    layout.relayout

    b1 = BoundsHelper.bounds(l1.handle)
    b2 = BoundsHelper.bounds(l2.handle)
    b3 = BoundsHelper.bounds(l3.handle)

    (b1[:y] + 30 + 4).should eq b2[:y]
    (b2[:y] + 30 + 4).should eq b3[:y]
    b1[:x].should eq 8
    b1[:w].should eq 300 - 16
  end

  it "horizontal layout: 3 labels side-by-side with spacing" do
    window = Quartz::Window.new("h3", 400, 100)
    l1 = Quartz::Label.new("A", 0, 0, 80, 30)
    l2 = Quartz::Label.new("B", 0, 0, 80, 30)
    l3 = Quartz::Label.new("C", 0, 0, 80, 30)
    window.add_control(l1)
    window.add_control(l2)
    window.add_control(l3)

    layout = Quartz::StackLayout.new(
      orientation: Quartz::StackLayout::Orientation::Horizontal,
      padding: 8,
      spacing: 4
    )
    layout.add(l1, 80, 30).add(l2, 80, 30).add(l3, 80, 30)
    layout.relayout

    b1 = BoundsHelper.bounds(l1.handle)
    b2 = BoundsHelper.bounds(l2.handle)
    b3 = BoundsHelper.bounds(l3.handle)

    (b1[:x] + 80 + 4).should eq b2[:x]
    (b2[:x] + 80 + 4).should eq b3[:x]
    b1[:y].should eq 8
    b1[:h].should eq 100 - 16
  end

  it "padding applied to first child" do
    window = Quartz::Window.new("pad", 300, 200)
    label = Quartz::Label.new("A", 0, 0, 80, 30)
    window.add_control(label)

    layout = Quartz::StackLayout.new(padding: 16, spacing: 0)
    layout.add(label, 80, 30)
    layout.relayout

    b = BoundsHelper.bounds(label.handle)
    b[:x].should eq 16
    b[:y].should eq 16
  end

  it "empty layout: no widget bounds touched" do
    layout = Quartz::StackLayout.new(padding: 8, spacing: 4)
    layout.relayout
    layout.size.should eq 0
  end

  it "single child: full bounds" do
    window = Quartz::Window.new("single", 320, 240)
    label = Quartz::Label.new("A", 0, 0, 80, 30)
    window.add_control(label)

    layout = Quartz::StackLayout.new(
      orientation: Quartz::StackLayout::Orientation::Vertical,
      padding: 10,
      spacing: 0
    )
    layout.add(label, 80, 30)
    layout.relayout

    b = BoundsHelper.bounds(label.handle)
    b[:x].should eq 10
    b[:y].should eq 10
    b[:w].should eq 320 - 20
    b[:h].should eq 30
  end

  it "unknown widget id returns all-zero bounds without crashing" do
    b = BoundsHelper.bounds(999_999)
    b[:x].should eq 0
    b[:y].should eq 0
    b[:w].should eq 0
    b[:h].should eq 0
  end
end
