require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

require  File.join( File.dirname(__FILE__),  "fooclass" )

describe "adding an immidiate update request" do
  before(:each) do
    Foo.all.destroy!
  end
  it "with a class target" do
    u = Update.immidiate(Foo,:bar,[])
    u.target.should == Foo
    Update.current.get(u.id).should_not be_nil
    Update.delayed.should == 0
  end
  
  it "with an conforming instance target" do
    f = Foo.create
    u = Update.immidiate(f,:bar,[])
    u.target.should == f
    Update.current.get(u.id).should_not be_nil
    Update.delayed.should == 0
  end
  
  it "with an custome finder" do
    f = Foo.create(:name=>'baz')
    u = Update.immidiate(Foo,:bar,[],:finder=>:first, :finder_args=>[{:name=>'baz'}])
    u.target.should == f
    Update.current.get(u.id).should_not be_nil
    Update.delayed.should == 0
  end
  
end

describe "chained request" do
  before :each do
    Update.clear_all
  end
  
  it "should not be in current or delayed queue" do
    u = Update.chain(Foo,:bar,[:error])
    u.time.should be_nil
    Update.current.should_not include(u)
    Update.delayed.should == 0
  end
  
  it "should be persistant" do
    u = Update.chain(Foo,:bar,[:error])
    u.should be_persistant
  end
  
end
 
describe "adding an delayed update request" do
  before :each do
    Update.clear_all
    Foo.all.destroy
  end

  
  it "with a class target" do
    u = Update.at(Chronic.parse('tomorrow'),Foo,:bar,[])
    u.target.should == Foo
    Update.current.should_not include(u)
    Update.delayed.should  == 1
  end
  
  it "with an conforming instance target" do
    f = Foo.create
    u = Update.at(Chronic.parse('tomorrow'),f,:bar,[])
    u.target.should == f
    Update.current.should_not include(u)
    Update.delayed.should == 1
  end
  
  it "with an custome finder" do
    f = Foo.create(:name=>'baz')
    u = Update.at(Chronic.parse('tomorrow'),Foo,:bar,[],:finder=>:first, :finder_args=>[{:name=>'baz'}])
    u.target.should == f
    Update.current.should_not include(u)
    Update.delayed.should == 1
  end
  
end




