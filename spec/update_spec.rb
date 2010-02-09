require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

describe Update do
  
  class Foo
    include DataMapper::Resource
    
    property :id, Serial
    property :name, String
    
    def bar(*args)
      Foo.bar(:instance,*args)
    end
    
  end
  
  Foo.auto_migrate!
  
  before(:each) do
    Foo.all.destroy!
  end
  
  
  it "should have a version matching the VERSION file" do
    Updater::VERSION.should == File.read(File.join(ROOT,'VERSION')).strip
  end
  
end