require File.join( File.dirname(__FILE__),  "spec_helper" )

describe Updater do
  
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
  
  it "should include DataMapper::Resource" do
    DataMapper::Resource.descendants.to_a.should include(Updater)
  end
  
  it "should have a version matching the VERSION file" do
    Updater::VERSION.should == File.read(File.join(ROOT,'VERSION')).strip
  end
  
  describe "adding an immidiate update request" do
    
    it "with a class target" do
      u = Updater.immidiate(Foo,:bar,[])
      u.target.should == Foo
      Updater.current.should include(u)
      Updater.delayed.should_not include(u)
    end
    
    it "with an conforming instance target" do
      f = Foo.create
      u = Updater.immidiate(f,:bar,[])
      u.target.should == f
      Updater.current.should include(u)
      Updater.delayed.should_not include(u)
    end
    
    it "with an custome finder" do
      f = Foo.create(:name=>'baz')
      u = Updater.immidiate(Foo,:bar,[],:finder=>:first, :finder_args=>{:name=>'baz'})
      u.target.should == f
      Updater.current.should include(u)
      Updater.delayed.should_not include(u)
    end
    
  end
  
  describe "chained request" do
    
    it "should not be in current or delayed queue" do
      u = Updater.chain(Foo,:bar,[:error])
      u.time.should be_nil
      Updater.current.should_not include(u)
      Updater.delayed.should_not include(u)
    end
    
  end
  
  describe "named request" do
    
    it "should be found by name when instance" do
      f = Foo.create(:name=>'Honey')
      u = Updater.immidiate(f,:bar,[:named],:name=>'Now')
      u.name.should ==("Now")
      Updater.for(f, "Now").should ==(u)
    end
    
    it "should be found by name when class" do
      u = Updater.immidiate(Foo,:bar,[:named],:name=>'Now')
      u.name.should ==("Now")
      Updater.for(Foo, "Now").should ==(u)
    end
    
  end
  
  describe "adding an delayed update request" do
    
    it "with a class target" do
      u = Updater.at(Chronic.parse('tomorrow'),Foo,:bar,[])
      u.target.should == Foo
      Updater.current.should_not include(u)
      Updater.delayed.should include(u)
    end
    
    it "with an conforming instance target" do
      f = Foo.create
      u = Updater.at(Chronic.parse('tomorrow'),f,:bar,[])
      u.target.should == f
      Updater.current.should_not include(u)
      Updater.delayed.should include(u)
    end
    
    it "with an custome finder" do
      f = Foo.create(:name=>'baz')
      u = Updater.at(Chronic.parse('tomorrow'),Foo,:bar,[],:finder=>:first, :finder_args=>{:name=>'baz'})
      u.target.should == f
      Updater.current.should_not include(u)
      Updater.delayed.should include(u)
    end
    
  end
  
  describe "running an update" do
    
    it "should call the named method with a class target" do
      u = Updater.immidiate(Foo,:bar,[:arg1,:arg2])
      Foo.should_receive(:bar).with(:arg1,:arg2)
      u.run
    end
    
    it "should call the named method with an conforming instance target" do
      f = Foo.create
      u = Updater.immidiate(f,:bar,[:arg1,:arg2])
      Foo.should_receive(:bar).with(:instance,:arg1,:arg2)
      u.run
    end
    
    it "should return all updates for a given target" do
      u1 = Updater.immidiate(Foo,:bar,[:arg1,:arg2])
      u2 = Updater.immidiate(Foo,:bar,[:arg3,:arg4])
      Updater.for(Foo).should include(u1,u2)
    end
    
    describe "Error Handeling" do
      it "should trap errors" do
        u = Updater.immidiate(Foo,:bar,[:arg1,:arg2])
        Foo.should_receive(:bar).with(:arg1,:arg2).and_raise(RuntimeError)
        lambda {u.run}.should_not raise_error
      end
      
      it "should run the failure task" do
        err = Updater.chain(Foo,:bar,[:error])
        u = Updater.immidiate(Foo,:bar,[:arg1,:arg2],:failure=>err)
        Foo.should_receive(:bar).with(:arg1,:arg2).and_raise(RuntimeError)
        Foo.should_receive(:bar).with(:error)
        u.run
      end
    end
  end
  
end
