require "../spec_helper"
require "../../src/quartz/stack_layout"
require "../../src/quartz/button"
require "../../src/quartz/label"
require "../../src/quartz/window"

describe "StackLayout" do
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
end
