require File.join( File.dirname(__FILE__),  "spec_helper" )

describe Foo do
  before :each do
    Foo.reset 
  end
  
  it "should have an unique index function" do
    i1 = Foo.index
    i2 = Foo.index
    i1.should_not be_nil
    i2.should_not be_nil
    i1.should_not == i2
  end
  
  it "should instantiate a new instance with an id" do
    foo = Foo.new
    foo.id.should_not be_nil
  end
  
  it "should create saved instances" do
    foo = Foo.create
    Foo.find(foo.id).should be(foo)
  end
  
  it "should have a name I can set" do
    foo = Foo.create(:name=>'bar')
    foo.name.should == 'bar'
    foo.name = 'baz'
    foo.name.should == 'baz'
  end
  
  it "should have a count" do
    Foo.count.should == 0
    foo = Foo.create(:name=>'bar')
    Foo.count.should == 1
  end
end