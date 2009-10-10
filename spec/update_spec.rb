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
  
  it "should include DataMapper::Resource" do
    DataMapper::Model.descendants.to_a.should include(Update)
  end
  
  it "should have a version matching the VERSION file" do
    Updater::VERSION.should == File.read(File.join(ROOT,'VERSION')).strip
  end
  
  describe "adding an immidiate update request" do
    
    it "with a class target" do
      u = Update.immidiate(Foo,:bar,[])
      u.target.should == Foo
      Update.current.should include(u)
      Update.delayed.should_not include(u)
    end
    
    it "with an conforming instance target" do
      f = Foo.create
      u = Update.immidiate(f,:bar,[])
      u.target.should == f
      Update.current.should include(u)
      Update.delayed.should_not include(u)
    end
    
    it "with an custome finder" do
      f = Foo.create(:name=>'baz')
      u = Update.immidiate(Foo,:bar,[],:finder=>:first, :finder_args=>{:name=>'baz'})
      u.target.should == f
      Update.current.should include(u)
      Update.delayed.should_not include(u)
    end
    
  end
  
  describe "chained request" do
    
    it "should not be in current or delayed queue" do
      u = Update.chain(Foo,:bar,[:error])
      u.time.should be_nil
      Update.current.should_not include(u)
      Update.delayed.should_not include(u)
    end
    
  end
  
  describe "named request" do
    
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
      u1 = Update.immidiate(Foo,:bar,[:arg1,:arg2])
      u2 = Update.immidiate(Foo,:bar,[:arg3,:arg4])
      Update.for(Foo).should include(u1,u2)
    end

    
  end
  
  describe "adding an delayed update request" do
    
    it "with a class target" do
      u = Update.at(Chronic.parse('tomorrow'),Foo,:bar,[])
      u.target.should == Foo
      Update.current.should_not include(u)
      Update.delayed.should include(u)
    end
    
    it "with an conforming instance target" do
      f = Foo.create
      u = Update.at(Chronic.parse('tomorrow'),f,:bar,[])
      u.target.should == f
      Update.current.should_not include(u)
      Update.delayed.should include(u)
    end
    
    it "with an custome finder" do
      f = Foo.create(:name=>'baz')
      u = Update.at(Chronic.parse('tomorrow'),Foo,:bar,[],:finder=>:first, :finder_args=>{:name=>'baz'})
      u.target.should == f
      Update.current.should_not include(u)
      Update.delayed.should include(u)
    end
    
  end
  
  describe "running an update" do
    
    before :each do
      Update.all.destroy!
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
    
    it "should not delete the record if it is a chain record" do
      u = Update.chain(Foo,:bar,[:arg1,:arg2])
      Foo.should_receive(:bar).with(:arg1,:arg2).and_raise(RuntimeError)
      u.run
      u.should be_saved
    end
    
    describe "Error Handeling" do
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
        err = Update.chain(Foo,:bar,[:error])
        u = Update.immidiate(Foo,:bar,[:arg1,:arg2],:failure=>err)
        Foo.should_receive(:bar).with(:arg1,:arg2).and_raise(RuntimeError)
        Foo.should_receive(:bar).with(:error)
        u.run
      end
    end
  end
  
end
