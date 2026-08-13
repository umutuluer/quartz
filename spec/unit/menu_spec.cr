require "../spec_helper"

describe "Menu" do
  it "MenuBar creates native handle" do
    bar = Quartz::MenuBar.new
    bar.handle.should be > 0
  end

  it "ContextMenu creates native handle" do
    cm = Quartz::ContextMenu.new
    cm.handle.should be > 0
  end

  it "MenuItem creates native handle with text" do
    item = Quartz::MenuItem.new("Quit")
    item.handle.should be > 0
    item.text.should eq "Quit"
  end

  it "MenuItem.on_click returns self (zincirleme)" do
    item = Quartz::MenuItem.new("Quit")
    item.on_click { 0 }.should be(item)
  end

  it "MenuSeparator creates native handle" do
    sep = Quartz::MenuSeparator.new
    sep.handle.should be > 0
  end

  it "MenuBar.add_item and add_separator chain" do
    bar = Quartz::MenuBar.new
    item = Quartz::MenuItem.new("Quit")
    item.on_click { 0 }
    bar.add_item(item).add_separator
    bar.items.size.should eq 2
  end

  it "ContextMenu.add_item chains" do
    cm = Quartz::ContextMenu.new
    cm.add_item("Copy") { 0 }
    cm.items.size.should eq 1
  end

  it "MenuItem._dispatch invokes registered callback" do
    item = Quartz::MenuItem.new("Test")
    called = 0
    item.on_click { called += 1 }
    Quartz::MenuItem._dispatch(item.handle)
    called.should eq 1
  end

  it "MenuItem._dispatch on unknown id is no-op" do
    Quartz::MenuItem._dispatch(-1) # no exception
  end
end
