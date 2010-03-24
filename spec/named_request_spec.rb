require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

require  File.join( File.dirname(__FILE__),  "fooclass" )

describe "named request" do
  
  before(:each) do
    Foo.all.destroy!
  end
  
  it "should be found by name when target is an instance" do
    f = Foo.create(:name=>'Honey')
    u = Update.immidiate(f,:bar,[:named],:name=>'Now')
    u.name.should ==("Now")
    Update.for(f, "Now").should ==(u)
  end
  
  it "should be found by name when target is a class" do
    u = Update.immidiate(Foo,:bar,[:named],:name=>'Now')
    u.name.should ==("Now")
    Update.for(Foo, "Now").should ==(u)
  end
  
  it "should return all updates for a given target" do
    u1 = Update.immidiate(Foo,:bar,[:arg1,:arg2], :name=>'First')
    u2 = Update.immidiate(Foo,:bar,[:arg3,:arg4])
    Update.for(Foo).should include(u1,u2)
  end
  
end