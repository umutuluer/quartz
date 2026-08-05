require "../spec_helper"

# Local shorthand around the shared WidgetFactory.
private def create_test_radio(text = "Test", x = 0, y = 0, width = 120, height = 25, checked = false)
  WidgetFactory.radio_button(text, x, y, width, height, checked: checked)
end

private def create_test_window(title = "Test Window", width = 400, height = 300)
  WidgetFactory.window(title, width, height)
end

describe Quartz::RadioButton do
  describe "type hierarchy" do
    it "inherits from Control" do
      rb = create_test_radio
      rb.should be_a(Quartz::Control)
    end

    it "is a RadioButton" do
      rb = create_test_radio
      rb.should be_a(Quartz::RadioButton)
    end
  end

  describe "#handle" do
    it "returns a positive handle" do
      rb = create_test_radio
      rb.handle.should be > 0
    end

    it "each radio button gets a unique handle" do
      r1 = create_test_radio
      r2 = create_test_radio
      r3 = create_test_radio
      handles = [r1.handle, r2.handle, r3.handle]
      handles.uniq.size.should eq(3)
    end
  end

  describe "#checked" do
    it "defaults to false" do
      rb = create_test_radio
      rb.checked.should be_false
    end

    it "can be initialised as checked" do
      rb = create_test_radio(checked: true)
      rb.checked.should be_true
    end

    it "setter updates the checked state" do
      rb = create_test_radio
      rb.checked = true
      rb.checked.should be_true
      rb.checked = false
      rb.checked.should be_false
    end

    it "idempotent setter does not raise" do
      rb = create_test_radio
      rb.checked = true
      rb.checked = true
      rb.checked.should be_true
    end
  end

  describe "#text=" do
    it "accepts a new label" do
      rb = create_test_radio("Option A")
      rb.text = "Option B"
    end

    it "accepts Turkish characters" do
      rb = create_test_radio("Test")
      rb.text = "Türkçe karakter: ğüşıöçĞÜŞİÖÇ"
    end
  end

  describe "#enabled=" do
    it "can be disabled and re-enabled" do
      rb = create_test_radio
      rb.enabled = false
      rb.enabled = true
    end
  end

  describe "._dispatch" do
    it "calls the registered callback" do
      called = false
      captured_id = 0

      rb = create_test_radio
      rb.on_checked_changed do
        called = true
        captured_id = rb.handle
      end

      Quartz::RadioButton._dispatch(rb.handle)

      called.should be_true
      captured_id.should eq(rb.handle)
    end

    it "is nil-safe when no callback is registered" do
      rb = create_test_radio
      Quartz::RadioButton._dispatch(rb.handle)
    end

    it "is nil-safe for unknown widget IDs" do
      Quartz::RadioButton._dispatch(999_999)
    end

    it "dispatches to the correct radio among many" do
      r1 = create_test_radio
      r2 = create_test_radio
      r3 = create_test_radio

      results = [] of Int32

      r1.on_checked_changed { results << 1 }
      r2.on_checked_changed { results << 2 }
      r3.on_checked_changed { results << 3 }

      Quartz::RadioButton._dispatch(r2.handle)
      results.should eq([2])

      Quartz::RadioButton._dispatch(r1.handle)
      results.should eq([2, 1])

      Quartz::RadioButton._dispatch(r3.handle)
      results.should eq([2, 1, 3])
    end
  end

  describe "#on_checked_changed" do
    it "replaces the previous callback" do
      rb = create_test_radio
      results = [] of String

      rb.on_checked_changed { results << "first" }
      rb.on_checked_changed { results << "second" }

      Quartz::RadioButton._dispatch(rb.handle)
      results.should eq(["second"])
    end
  end

  describe "radio exclusivity" do
    it "unchecks siblings when a radio is checked programmatically" do
      window = create_test_window
      rb1 = create_test_radio("A", checked: true)
      rb2 = create_test_radio("B", checked: false)

      window.add_control(rb1)
      window.add_control(rb2)

      rb1.checked.should be_true
      rb2.checked.should be_false

      rb2.checked = true

      rb2.checked.should be_true
      rb1.checked.should be_false
    end

    it "fires callbacks for both radios when exclusivity triggers" do
      window = create_test_window
      events = [] of {Int32, Bool}

      rb1 = create_test_radio("A", checked: true)
      rb2 = create_test_radio("B", checked: false)

      rb1.on_checked_changed { events << {1, rb1.checked} }
      rb2.on_checked_changed { events << {2, rb2.checked} }

      window.add_control(rb1)
      window.add_control(rb2)

      rb2.checked = true

      # Both radios fire their callback
      events.size.should eq(2)
      # rb1 fires with false (was true, now unchecked)
      events[0].should eq({1, false})
      # rb2 fires with true (was false, now checked)
      events[1].should eq({2, true})
    end

    it "does not affect radios in a different window" do
      w1 = create_test_window("Win 1", 400, 300)
      w2 = create_test_window("Win 2", 400, 300)

      rb1 = create_test_radio("A", checked: true)
      rb2 = create_test_radio("B", checked: true)

      w1.add_control(rb1)
      w2.add_control(rb2)

      rb1.checked.should be_true
      rb2.checked.should be_true

      # Checking a radio in w1 should not affect w2
      rb1.checked = true # already true, no-op
      rb2.checked.should be_true
    end

    it "allows the group to be selectionless (checked = false)" do
      window = create_test_window
      rb1 = create_test_radio("A", checked: true)
      rb2 = create_test_radio("B", checked: false)

      window.add_control(rb1)
      window.add_control(rb2)

      rb1.checked = false

      rb1.checked.should be_false
      rb2.checked.should be_false
    end

    it "does not fire callback when sibling checked= assigns same value" do
      window = create_test_window
      events = [] of Int32

      rb1 = create_test_radio("A", checked: false)
      rb2 = create_test_radio("B", checked: false)

      rb1.on_checked_changed { events << 1 }
      rb2.on_checked_changed { events << 2 }

      window.add_control(rb1)
      window.add_control(rb2)

      rb2.checked = false # already false, no event
      events.should eq([] of Int32)
    end

    it "when parent-added checked radio wins over existing checked sibling" do
      window = create_test_window

      rb1 = create_test_radio("A", checked: true)
      rb2 = create_test_radio("B", checked: true)

      window.add_control(rb1)
      window.add_control(rb2) # this triggers exclusivity via Crystal

      # Last-added radio with initial checked=true wins
      rb2.checked.should be_true
      rb1.checked.should be_false
    end
  end
end
