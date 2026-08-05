require "../spec_helper"

# Concrete subclass of the abstract Control for testing purposes.
# Wrapped in a `private` module so it doesn't leak into the global
# namespace and collide with other specs that may add their own
# doubles.
private module ControlSpec
  class TestControl < Quartz::Control
  end
end

describe Quartz::Control do
  describe "#handle" do
    it "returns the handle passed to the constructor" do
      ctrl = ControlSpec::TestControl.new(42)
      ctrl.handle.should eq(42)
    end

    it "works with negative handles" do
      ctrl = ControlSpec::TestControl.new(-1)
      ctrl.handle.should eq(-1)
    end

    it "works with zero handle" do
      ctrl = ControlSpec::TestControl.new(0)
      ctrl.handle.should eq(0)
    end
  end

  describe "#parent" do
    it "is nil by default" do
      ctrl = ControlSpec::TestControl.new(1)
      ctrl.parent.should be_nil
    end

    it "can be assigned" do
      parent = ControlSpec::TestControl.new(10)
      child = ControlSpec::TestControl.new(20)

      child.parent = parent
      child.parent.should eq(parent)
    end

    it "can be set to nil" do
      ctrl = ControlSpec::TestControl.new(1)
      ctrl.parent = ControlSpec::TestControl.new(2)
      ctrl.parent.nil?.should be_false

      ctrl.parent = nil
      ctrl.parent.nil?.should be_true
    end
  end
end
