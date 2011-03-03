require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

describe "named request" do
  
  before(:each) do
    Foo.reset
    Update.clear_all
  end
  
  it "should be found by name when target is an instance" do
    f = Foo.create(:name=>'Honey')
    u = Update.immidiate(f,:bar,[:named],:name=>'Now')
    u.name.should ==("Now")
    pending "ORM#for"
    Update.for(f, "Now").should ==(u)
  end
  
  it "should be found by name when target is a class" do
    u = Update.immidiate(Foo,:bar,[:named],:name=>'Now')
    u.name.should ==("Now")
    pending "ORM#for"
    Update.for(Foo, "Now").should ==(u)
  end
  
  it "should return all updates for a given target" do
    u1 = Update.immidiate(Foo,:bar,[:arg1,:arg2], :name=>'First')
    u2 = Update.immidiate(Foo,:bar,[:arg3,:arg4])
    pending "ORM#for"
    Update.for(Foo).should include(u1,u2)
  end
  
  #locked updates are already running and can therefore not be modified
  it "should not include locked updates" do
    u = Update.immidiate(Foo,:bar,[:named],:name=>'Now')
    u.orm.lock(Struct.new(:name).new('test_worker'))
    pending "ORM#for"
    Update.for(Foo).should_not include(u)
    Update.for(Foo).should be_empty
  end
  
  it "should not return rusults with the wrong name" do
    u = Update.immidiate(Foo,:bar,[:named],:name=>'Now')
    u.name.should ==("Now")
    pending "ORM#for"
    Update.for(Foo, "Then").should be_nil
  end
  
  it "should not return results for the wring target" do
    f = Foo.create(:name=>'Honey')
    g = Foo.create(:name=>'Sweetie Pie')
    u = Update.immidiate(f,:bar,[:named],:name=>'Now')
    pending "ORM#for"
    Update.for(f).should include(u)
    Update.for(g).should be_empty
  end
  
end