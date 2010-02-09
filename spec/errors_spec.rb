require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

require  File.join( File.dirname(__FILE__),  "fooclass" )

describe "Job Error Handeling" do
  before(:each) do
    Foo.all.destroy!
  end
  
  it "should return false when run" do
    u = Update.immidiate(Foo,:bar,[:arg1,:arg2])
    Foo.should_receive(:bar).with(:arg1,:arg2).and_raise(RuntimeError)
    u.run.should be_false
  end
  
  it "should trap errors" do
    u = Update.immidiate(Foo,:bar,[:arg1,:arg2])
    Foo.should_receive(:bar).with(:arg1,:arg2).and_raise(RuntimeError)
    lambda {u.run}.should_not raise_error
  end
  
  it "should run the failure task" do
    pending "Chained Method API"
    err = Update.chain(Foo,:bar,[:error])
    u = Update.immidiate(Foo,:bar,[:arg1,:arg2],:failure=>err)
    Foo.should_receive(:bar).with(:arg1,:arg2).and_raise(RuntimeError)
    Foo.should_receive(:bar).with(:error)
    u.run
  end
end