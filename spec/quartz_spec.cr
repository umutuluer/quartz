require "./spec_helper"

describe Quartz do
  describe "VERSION" do
    it "is defined" do
      Quartz::VERSION.should be_a(String)
    end

    it "is not empty" do
      Quartz::VERSION.empty?.should be_false
    end

    it "follows semver format (MAJOR.MINOR.PATCH)" do
      Quartz::VERSION.should match(/^\d+\.\d+\.\d+$/)
    end

    it "is a non-prerelease version" do
      # Should not contain pre-release suffixes like -alpha, -beta, -rc
      Quartz::VERSION.includes?("-").should be_false
    end
  end
end

# Per-class type-hierarchy coverage lives in spec/unit/<class>_spec.cr.
