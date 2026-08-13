require "./spec_helper"
require "../src/quartz/open_file_dialog"
require "../src/quartz/save_file_dialog"

# Contract with the C backends (ext/quartz_helper_*.{m,c,cpp}):
#
#   * `LibQuartz.quartz_test_dialog_set_mode(1)` arms the seam. While armed,
#     the native `quartz_open_file_dialog` / `quartz_save_file_dialog`
#     return a canned path instead of running a blocking modal.
#   * When `QUARTZ_TEST_DIALOG_PATH` is set to a non-empty value, that
#     value is returned as-is (used to simulate picking a specific file).
#   * When `QUARTZ_TEST_DIALOG_PATH` is set but EMPTY, the dialog reports a
#     cancel (`nil` in Crystal). This is how the cancel path is exercised
#     deterministically — the one place the spec touches the ENV, because a
#     real modal can never be driven headless.
#   * When the var is unset, a hardcoded default is returned:
#     `/tmp/quartz_test_open.txt` (open) and `/tmp/quartz_test_save.txt`
#     (save). The save mock also emulates the real dialog appending
#     `default_ext` when the returned name has no matching extension.
#
# Every example resets the mode and the env var so nothing leaks between
# examples (a real modal must NEVER be triggered by the suite).
describe Quartz::FileDialog do
  before_each do
    LibQuartz.quartz_test_dialog_set_mode(1)
  end

  after_each do
    LibQuartz.quartz_test_dialog_set_mode(0)
    ENV.delete("QUARTZ_TEST_DIALOG_PATH")
  end

  describe "OpenFileDialog with mock" do
    it "returns the default mock path on success" do
      dialog = Quartz::OpenFileDialog.new
      dialog.show_dialog.should eq "/tmp/quartz_test_open.txt"
    end

    it "returns a QUARTZ_TEST_DIALOG_PATH override when set" do
      ENV["QUARTZ_TEST_DIALOG_PATH"] = "/custom/override.txt"
      dialog = Quartz::OpenFileDialog.new
      dialog.show_dialog.should eq "/custom/override.txt"
    end

    it "returns nil when the mock is cancelled (empty path)" do
      ENV["QUARTZ_TEST_DIALOG_PATH"] = ""
      dialog = Quartz::OpenFileDialog.new
      dialog.show_dialog.should be_nil
    end

    it "show_multi returns an array on success" do
      dialog = Quartz::OpenFileDialog.new
      dialog.multiselect = true
      dialog.show_multi.should eq ["/tmp/quartz_test_open.txt"]
    end

    it "show_multi returns nil when the mock is cancelled" do
      ENV["QUARTZ_TEST_DIALOG_PATH"] = ""
      dialog = Quartz::OpenFileDialog.new
      dialog.multiselect = true
      dialog.show_multi.should be_nil
    end
  end

  describe "SaveFileDialog with mock" do
    it "returns the default mock path on success" do
      dialog = Quartz::SaveFileDialog.new
      dialog.show_dialog.should eq "/tmp/quartz_test_save.txt"
    end

    it "returns nil when the mock is cancelled (empty path)" do
      ENV["QUARTZ_TEST_DIALOG_PATH"] = ""
      dialog = Quartz::SaveFileDialog.new
      dialog.show_dialog.should be_nil
    end

    it "appends default_ext when the user omits it" do
      dialog = Quartz::SaveFileDialog.new
      dialog.default_ext = "log" # mock path ends in .txt, so this must be appended
      path = dialog.show_dialog
      path.should_not be_nil
      path.as(String).should end_with ".log"
    end
  end
end
