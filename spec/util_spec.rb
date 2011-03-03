require File.join( File.dirname(__FILE__),  "spec_helper" )

describe "Util.tempio" do
  
  it "should return an unlinked file" do
    Updater::Util.tempio.stat.nlink.should == 0
  end
  
end