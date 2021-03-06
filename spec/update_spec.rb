require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

describe Update do
  it "should have a version matching the VERSION file" do
    Updater::VERSION.should == File.read(File.join(ROOT,'VERSION')).strip
  end 
  
  it "should have its own inspect method" do
    Update.new(Update.orm.new).inspect.should =~ /Updater::Update/
  end

end

describe "Gemspec: " do
  it"should match version" do
    gs = File.open(File.join(ROOT,'updater.gemspec')) do |f|
      eval f.read
    end
    gs.version.to_s.should == File.read(File.join(ROOT,'VERSION')).strip
  end
end