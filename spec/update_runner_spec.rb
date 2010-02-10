require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

require  File.join( File.dirname(__FILE__),  "fooclass" )

describe "running an update" do
  
  before :each do
    Update.clear_all
    Foo.all.destroy!
  end
  
  it "should call the named method with a class target" do
    u = Update.immidiate(Foo,:bar,[:arg1,:arg2])
    Foo.should_receive(:bar).with(:arg1,:arg2)
    u.run
  end
  
  it "should call the named method with an conforming instance target" do
    f = Foo.create
    u = Update.immidiate(f,:bar,[:arg1,:arg2])
    Foo.should_receive(:bar).with(:instance,:arg1,:arg2)
    u.run
  end
  
  it "should delete the record once it is run" do
    u = Update.immidiate(Foo,:bar,[:arg1,:arg2])
    Foo.should_receive(:bar).with(:arg1,:arg2)
    u.run
    u.should_not be_saved #NOTE: not a theological statment
  end
  
  it "should delete the record if there is a failure" do
    u = Update.immidiate(Foo,:bar,[:arg1,:arg2])
    Foo.should_receive(:bar).with(:arg1,:arg2).and_raise(RuntimeError)
    u.run
    u.should_not be_saved #NOTE: not a theological statment
  end
  
  it "should NOT delete the record if it is a chain record" do
    u = Update.chain(Foo,:bar,[:arg1,:arg2])
    Foo.should_receive(:bar).with(:arg1,:arg2).and_raise(RuntimeError)
    u.run
    u.should be_saved
  end
  
end