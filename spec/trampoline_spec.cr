require "./spec_helper"

# These prove the *complete* native→Crystal callback path. Each
# LibQuartz.quartz_test_fire_* helper synthesises a native event on the C
# side, looks up the backend's callback registry (callbackMap / GHashTable /
# QMap / linked list) and invokes the C function pointer that Crystal
# registered. That pointer is the widget's `_dispatch` class method, which
# runs the block the example registered with on_click / on_text_changed /
# ... — exactly what a real UI event would do.
describe "Trampoline (native→block callback path)" do
  it "Button: quartz_test_fire_button_click invokes registered on_click" do
    button = WidgetFactory.button
    called = false
    captured_id = 0
    button.on_click do
      called = true
      captured_id = button.handle
    end
    LibQuartz.quartz_test_fire_button_click(button.handle)
    called.should be_true
    captured_id.should eq(button.handle)
  end

  it "Button: fires only the matching instance among many" do
    b1 = WidgetFactory.button
    b2 = WidgetFactory.button
    results = [] of Int32

    b1.on_click { results << 1 }
    b2.on_click { results << 2 }

    LibQuartz.quartz_test_fire_button_click(b2.handle)
    results.should eq([2])

    LibQuartz.quartz_test_fire_button_click(b1.handle)
    results.should eq([2, 1])
  end

  it "Button: unknown id is a no-op" do
    LibQuartz.quartz_test_fire_button_click(999_999)
  end

  it "Button: no registered callback is a no-op" do
    button = WidgetFactory.button
    LibQuartz.quartz_test_fire_button_click(button.handle)
  end

  it "CheckBox: quartz_test_fire_toggle_checked invokes on_checked_changed" do
    check = WidgetFactory.check_box
    called = false
    captured_id = 0
    check.on_checked_changed do
      called = true
      captured_id = check.handle
    end
    LibQuartz.quartz_test_fire_toggle_checked(check.handle)
    called.should be_true
    captured_id.should eq(check.handle)
  end

  it "CheckBox: fires only the matching instance among many" do
    c1 = WidgetFactory.check_box
    c2 = WidgetFactory.check_box
    results = [] of Int32

    c1.on_checked_changed { results << 1 }
    c2.on_checked_changed { results << 2 }

    LibQuartz.quartz_test_fire_toggle_checked(c2.handle)
    results.should eq([2])

    LibQuartz.quartz_test_fire_toggle_checked(c1.handle)
    results.should eq([2, 1])
  end

  it "CheckBox: unknown id is a no-op" do
    LibQuartz.quartz_test_fire_toggle_checked(999_999)
  end

  it "RadioButton: quartz_test_fire_toggle_checked invokes on_checked_changed" do
    radio = WidgetFactory.radio_button
    called = false
    captured_id = 0
    radio.on_checked_changed do
      called = true
      captured_id = radio.handle
    end
    LibQuartz.quartz_test_fire_toggle_checked(radio.handle)
    called.should be_true
    captured_id.should eq(radio.handle)
  end

  it "RadioButton: fires only the matching instance among many" do
    r1 = WidgetFactory.radio_button
    r2 = WidgetFactory.radio_button
    results = [] of Int32

    r1.on_checked_changed { results << 1 }
    r2.on_checked_changed { results << 2 }

    LibQuartz.quartz_test_fire_toggle_checked(r2.handle)
    results.should eq([2])

    LibQuartz.quartz_test_fire_toggle_checked(r1.handle)
    results.should eq([2, 1])
  end

  it "RadioButton: unknown id is a no-op" do
    LibQuartz.quartz_test_fire_toggle_checked(999_999)
  end

  it "TextBox: quartz_test_fire_text_change invokes on_text_changed" do
    textbox = WidgetFactory.textbox
    called = false
    captured_id = 0
    textbox.on_text_changed do
      called = true
      captured_id = textbox.handle
    end
    LibQuartz.quartz_test_fire_text_change(textbox.handle)
    called.should be_true
    captured_id.should eq(textbox.handle)
  end

  it "TextBox: fires only the matching instance among many" do
    t1 = WidgetFactory.textbox
    t2 = WidgetFactory.textbox
    results = [] of Int32

    t1.on_text_changed { results << 1 }
    t2.on_text_changed { results << 2 }

    LibQuartz.quartz_test_fire_text_change(t2.handle)
    results.should eq([2])

    LibQuartz.quartz_test_fire_text_change(t1.handle)
    results.should eq([2, 1])
  end

  it "TextBox: unknown id is a no-op" do
    LibQuartz.quartz_test_fire_text_change(999_999)
  end

  it "ListBox: quartz_test_fire_listbox_selection invokes on_selection_changed" do
    listbox = WidgetFactory.listbox
    listbox.add_item("A")
    listbox.add_item("B")
    listbox.selected_index = 1

    called = false
    captured_id = 0
    listbox.on_selection_changed do
      called = true
      captured_id = listbox.handle
    end
    LibQuartz.quartz_test_fire_listbox_selection(listbox.handle)
    called.should be_true
    captured_id.should eq(listbox.handle)
  end

  it "ListBox: unknown id is a no-op" do
    LibQuartz.quartz_test_fire_listbox_selection(999_999)
  end

  it "ComboBox: quartz_test_fire_combobox_selection invokes on_selection_changed" do
    combo = WidgetFactory.combobox
    combo.add_item("A")
    combo.add_item("B")
    combo.selected_index = 1

    called = false
    captured_id = 0
    combo.on_selection_changed do
      called = true
      captured_id = combo.handle
    end
    LibQuartz.quartz_test_fire_combobox_selection(combo.handle)
    called.should be_true
    captured_id.should eq(combo.handle)
  end

  it "ComboBox: unknown id is a no-op" do
    LibQuartz.quartz_test_fire_combobox_selection(999_999)
  end

  it "ComboBox text: quartz_test_fire_combobox_text invokes on_text_changed" do
    combo = WidgetFactory.combobox(editable: true)
    called = false
    captured_id = 0
    combo.on_text_changed do
      called = true
      captured_id = combo.handle
    end
    LibQuartz.quartz_test_fire_combobox_text(combo.handle)
    called.should be_true
    captured_id.should eq(combo.handle)
  end

  it "ComboBox text: unknown id is a no-op" do
    LibQuartz.quartz_test_fire_combobox_text(999_999)
  end

  it "MenuItem: quartz_test_fire_menu_item invokes registered on_click" do
    item = Quartz::MenuItem.new("Quit")
    called = false
    captured_id = 0
    item.on_click do
      called = true
      captured_id = item.handle
    end
    LibQuartz.quartz_test_fire_menu_item(item.handle)
    called.should be_true
    captured_id.should eq(item.handle)
  end

  it "MenuItem: unknown id is a no-op" do
    LibQuartz.quartz_test_fire_menu_item(999_999)
  end
end
