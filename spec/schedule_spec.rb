require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

describe "adding an immidiate update request" do
  before :all do
    @orm = Update.orm
  end
  
  before(:each) do
    Foo.reset
  end
  
  specify "with a class target" do
    u = Update.immidiate(Foo,:bar,[])
    u.target.should == Foo
    @orm.current.should include(u.orm)
    Update.delayed.should == 0
  end
  
  it "with an conforming instance target" do
    f = Foo.create
    u = Update.immidiate(f,:bar,[])
    u.target.should == f
    @orm.current.should include(u.orm)
    Update.delayed.should == 0
  end
  
  it "with an custome finder" do
    f = Foo.create(:name=>'baz')
    Foo.should_receive(:first).with(:name=>'baz').and_return f
    u = Update.immidiate(Foo,:bar,[],:finder=>:first, :finder_args=>[{:name=>'baz'}])
    u.target.should == f
    @orm.current.should include(u.orm)
    Update.delayed.should == 0
  end
  
end

describe "chained request" do
  before :all do
    @orm = Update.orm
  end
  
  before :each do
    Update.clear_all
  end
  
  it "should not be in current or delayed queue" do
    u = Update.chain(Foo,:bar,[:error])
    u.time.should be_nil
    @orm.current.should_not include(u.orm)
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
    Foo.reset
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
    Foo.should_receive(:first).with(:name=>'baz').and_return f
    u = Update.at(Chronic.parse('tomorrow'),Foo,:bar,[],:finder=>:first, :finder_args=>[{:name=>'baz'}])
    u.target.should == f
    Update.current.should_not include(u)
    Update.delayed.should == 1
  end
  
end




