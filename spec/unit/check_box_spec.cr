require "../spec_helper"

describe Quartz::CheckBox do
  describe "type hierarchy" do
    it "inherits from Control" do
      cb = WidgetFactory.check_box
      cb.should be_a(Quartz::Control)
    end

    it "is a CheckBox" do
      cb = WidgetFactory.check_box
      cb.should be_a(Quartz::CheckBox)
    end
  end

  describe "#handle" do
    it "returns a positive handle" do
      cb = WidgetFactory.check_box
      cb.handle.should be > 0
    end

    it "each checkbox gets a unique handle" do
      c1 = WidgetFactory.check_box
      c2 = WidgetFactory.check_box
      c3 = WidgetFactory.check_box
      handles = [c1.handle, c2.handle, c3.handle]
      handles.uniq.size.should eq(3)
    end
  end

  describe "#checked" do
    it "defaults to false" do
      cb = WidgetFactory.check_box
      cb.checked.should be_false
    end

    it "can be initialised as checked" do
      cb = WidgetFactory.check_box(checked: true)
      cb.checked.should be_true
    end

    it "setter updates the checked state" do
      cb = WidgetFactory.check_box
      cb.checked = true
      cb.checked.should be_true
      cb.checked = false
      cb.checked.should be_false
    end

    it "idempotent setter does not raise" do
      cb = WidgetFactory.check_box
      cb.checked = true
      cb.checked = true
      cb.checked.should be_true

      cb.checked = false
      cb.checked = false
      cb.checked.should be_false
    end
  end

  describe "#text=" do
    it "accepts a new label" do
      cb = WidgetFactory.check_box("Enable")
      # No getter in V1, just verify it doesn't raise
      cb.text = "Disable"
    end

    it "accepts Turkish characters" do
      cb = WidgetFactory.check_box("Test")
      cb.text = "Türkçe karakter: ğüşıöçĞÜŞİÖÇ"
    end

    it "accepts empty string" do
      cb = WidgetFactory.check_box("Test")
      cb.text = ""
    end
  end

  describe "#enabled=" do
    it "can be disabled" do
      cb = WidgetFactory.check_box
      cb.enabled = false
    end

    it "can be re-enabled" do
      cb = WidgetFactory.check_box
      cb.enabled = false
      cb.enabled = true
    end
  end

  describe "._dispatch" do
    it "calls the registered callback" do
      called = false
      captured_id = 0

      cb = WidgetFactory.check_box
      cb.on_checked_changed do
        called = true
        captured_id = cb.handle
      end

      Quartz::CheckBox._dispatch(cb.handle)

      called.should be_true
      captured_id.should eq(cb.handle)
    end

    it "is nil-safe when no callback is registered" do
      cb = WidgetFactory.check_box
      Quartz::CheckBox._dispatch(cb.handle)
    end

    it "is nil-safe for unknown widget IDs" do
      Quartz::CheckBox._dispatch(999_999)
    end

    it "dispatches to the correct checkbox among many" do
      c1 = WidgetFactory.check_box
      c2 = WidgetFactory.check_box
      c3 = WidgetFactory.check_box

      results = [] of Int32

      c1.on_checked_changed { results << 1 }
      c2.on_checked_changed { results << 2 }
      c3.on_checked_changed { results << 3 }

      Quartz::CheckBox._dispatch(c2.handle)
      results.should eq([2])

      Quartz::CheckBox._dispatch(c1.handle)
      results.should eq([2, 1])

      Quartz::CheckBox._dispatch(c3.handle)
      results.should eq([2, 1, 3])
    end
  end

  describe "#on_checked_changed" do
    it "replaces the previous callback" do
      cb = WidgetFactory.check_box
      results = [] of String

      cb.on_checked_changed { results << "first" }
      cb.on_checked_changed { results << "second" }

      Quartz::CheckBox._dispatch(cb.handle)
      results.should eq(["second"])
    end

    it "fires when checked changes programmatically" do
      cb = WidgetFactory.check_box
      call_count = 0

      cb.on_checked_changed { call_count += 1 }

      cb.checked = true
      call_count.should eq(1)

      cb.checked = false
      call_count.should eq(2)
    end

    it "does not fire when checked is set to same value" do
      cb = WidgetFactory.check_box
      call_count = 0

      cb.on_checked_changed { call_count += 1 }

      cb.checked = true
      cb.checked = true
      call_count.should eq(1)

      cb.checked = false
      cb.checked = false
      call_count.should eq(2)
    end
  end
end
