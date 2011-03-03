require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

describe "running an update" do
  
  before :each do
    Update.clear_all
    Foo.reset
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
    Update.orm.get(u.orm.id).should be_nil
  end
  
  it "should delete the record if there is a failure" do
    u = Update.immidiate(Foo,:bar,[:arg1,:arg2])
    Foo.should_receive(:bar).with(:arg1,:arg2).and_raise(RuntimeError)
    u.run
    Update.orm.get(u.orm.id).should be_nil
  end
  
  it "should NOT delete the record if it is a chain record" do
    u = Update.chain(Foo,:bar,[:arg1,:arg2])
    Foo.should_receive(:bar).with(:arg1,:arg2).and_raise(RuntimeError)
    u.run
    Update.orm.get(u.orm.id).should_not be_nil
  end
  
end