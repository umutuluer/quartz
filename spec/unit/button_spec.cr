require "../spec_helper"

# Local shorthand around the shared WidgetFactory.
private def create_test_button(text = "Test", x = 0, y = 0, width = 100, height = 30)
  WidgetFactory.button(text, x, y, width, height)
end

describe Quartz::Button do
  describe "type hierarchy" do
    it "inherits from Control" do
      button = create_test_button
      button.should be_a(Quartz::Control)
    end

    it "is a Button" do
      button = create_test_button
      button.should be_a(Quartz::Button)
    end
  end

  describe "#handle" do
    it "returns a positive handle" do
      button = create_test_button
      button.handle.should be > 0
    end

    it "each button gets a unique handle" do
      b1 = create_test_button
      b2 = create_test_button
      b3 = create_test_button
      handles = [b1.handle, b2.handle, b3.handle]
      handles.uniq.size.should eq(3)
    end
  end

  describe "._dispatch" do
    it "calls the registered callback" do
      called = false
      captured_id = 0

      button = create_test_button
      button.on_click do
        called = true
        captured_id = button.handle
      end

      Quartz::Button._dispatch(button.handle)

      called.should be_true
      captured_id.should eq(button.handle)
    end

    it "is nil-safe when no callback is registered" do
      button = create_test_button
      # _dispatch on a handle with no callback should not raise
      Quartz::Button._dispatch(button.handle)
    end

    it "is nil-safe for unknown widget IDs" do
      Quartz::Button._dispatch(999_999)
    end

    it "dispatches to the correct button among many" do
      b1 = create_test_button
      b2 = create_test_button
      b3 = create_test_button

      results = [] of Int32

      b1.on_click { results << 1 }
      b2.on_click { results << 2 }
      b3.on_click { results << 3 }

      Quartz::Button._dispatch(b2.handle)
      results.should eq([2])

      Quartz::Button._dispatch(b1.handle)
      results.should eq([2, 1])

      Quartz::Button._dispatch(b3.handle)
      results.should eq([2, 1, 3])
    end
  end

  describe "#on_click" do
    it "replaces the previous callback" do
      button = create_test_button
      results = [] of String

      button.on_click { results << "first" }
      button.on_click { results << "second" }

      Quartz::Button._dispatch(button.handle)
      results.should eq(["second"])
    end
  end
end
