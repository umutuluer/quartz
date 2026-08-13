require "../spec_helper"

describe Quartz::MenuBar do
  it "MenuBar creates native handle" do
    bar = Quartz::MenuBar.new
    bar.handle.should be > 0
  end

  it "MenuBar.add_item and add_separator chain" do
    bar = Quartz::MenuBar.new
    item = Quartz::MenuItem.new("Quit")
    item.on_click { 0 }
    bar.add_item(item).add_separator
    bar.items.size.should eq 2
  end

  it "MenuBar.add_item(text, &block) chains and fires callback" do
    bar = Quartz::MenuBar.new
    count = 0
    bar.add_item("Quit") { count += 1 }.should be(bar)
    bar.items.size.should eq 1

    Quartz::MenuItem._dispatch(bar.items.first.handle)
    count.should eq 1
  end
end

describe Quartz::ContextMenu do
  it "ContextMenu creates native handle" do
    cm = Quartz::ContextMenu.new
    cm.handle.should be > 0
  end

  it "ContextMenu.add_item chains" do
    cm = Quartz::ContextMenu.new
    cm.add_item("Copy") { 0 }
    cm.items.size.should eq 1
  end

  it "dispatches clicks from a control-bound context menu" do
    cm = Quartz::ContextMenu.new
    results = [] of String
    cm.add_item("Copy") { results << "copy" }
    cm.add_item("Paste") { results << "paste" }

    btn = WidgetFactory.button("Right-click me")
    (btn.context_menu = cm).should be(btn)

    cm.items.size.should eq 2
    cm.items[0].should be_a(Quartz::MenuItem)
    cm.items[1].should be_a(Quartz::MenuItem)

    Quartz::MenuItem._dispatch(cm.items[0].as(Quartz::MenuItem).handle)
    results.should eq ["copy"]

    Quartz::MenuItem._dispatch(cm.items[1].as(Quartz::MenuItem).handle)
    results.should eq ["copy", "paste"]
  end
end

describe Quartz::MenuItem do
  it "MenuItem creates native handle with text" do
    item = Quartz::MenuItem.new("Quit")
    item.handle.should be > 0
    item.text.should eq "Quit"
  end

  it "MenuItem.on_click returns self (zincirleme)" do
    item = Quartz::MenuItem.new("Quit")
    item.on_click { 0 }.should be(item)
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

  it "MenuItem._dispatch is nil-safe before any callback is registered" do
    item = Quartz::MenuItem.new("No handler")
    Quartz::MenuItem._dispatch(item.handle) # no exception
  end

  it "each on_click call returns self for chaining" do
    item = Quartz::MenuItem.new("Quit")
    item.on_click { 1 }.should be(item)
    item.on_click { 2 }.should be(item)
    item.on_click { 3 }.should be(item)
  end
end

describe Quartz::MenuSeparator do
  it "MenuSeparator creates native handle" do
    sep = Quartz::MenuSeparator.new
    sep.handle.should be > 0
  end
end
