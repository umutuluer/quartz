require "../spec_helper"

describe Quartz::Application do
  describe "class structure" do
    it "can be instantiated" do
      app = Quartz::Application.new
      app.should be_a(Quartz::Application)
    end

    it "exposes a .run class method" do
      Quartz::Application.responds_to?(:run).should be_true
    end

    it "exposes an .exit class method" do
      Quartz::Application.responds_to?(:exit).should be_true
    end
  end

  # NOTE: .run starts the native event loop (blocking), so it cannot
  # be tested in a standard spec. .exit forwards to
  # LibQuartz.quartz_terminate, which is also only meaningful inside
  # an active event loop on every backend (GTK calls gtk_main_quit,
  # Qt calls QApplication::quit, AppKit sends -terminate:). Both
  # belong in an integration/ test suite that runs in a separate
  # process.
end
