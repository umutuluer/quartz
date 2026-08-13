require "../spec_helper"
require "../../src/quartz/open_file_dialog"
require "../../src/quartz/save_file_dialog"

describe Quartz::FileDialog do
  it "OpenFileDialog has default empty properties" do
    d = Quartz::OpenFileDialog.new
    d.title.should eq ""
    d.filter.should eq ""
    d.initial_directory.should eq ""
    d.file_name.should eq ""
    d.default_ext.should eq ""
    d.multiselect?.should be_false
  end

  it "SaveFileDialog has default empty properties" do
    d = Quartz::SaveFileDialog.new
    d.title.should eq ""
    d.overwrite_prompt?.should be_true
  end

  it "OpenFileDialog properties are settable" do
    d = Quartz::OpenFileDialog.new
    d.title = "Aç"
    d.filter = "Metin (*.txt)|*.txt"
    d.initial_directory = "/tmp"
    d.file_name = "test.txt"
    d.default_ext = "txt"
    d.multiselect = true
    d.title.should eq "Aç"
    d.filter.should eq "Metin (*.txt)|*.txt"
    d.initial_directory.should eq "/tmp"
    d.file_name.should eq "test.txt"
    d.default_ext.should eq "txt"
    d.multiselect?.should be_true
  end

  it "SaveFileDialog properties are settable" do
    d = Quartz::SaveFileDialog.new
    d.title = "Kaydet"
    d.filter = "Tümü (*.*)|*.*"
    d.overwrite_prompt = false
    d.title.should eq "Kaydet"
    d.filter.should eq "Tümü (*.*)|*.*"
    d.overwrite_prompt?.should be_false
  end
end
