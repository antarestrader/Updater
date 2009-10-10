require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

describe "Update Locking:" do
  
  class Foo
    include DataMapper::Resource
    
    property :id, Serial
    property :name, String
    
    def bar(*args)
      Foo.bar(:instance,*args)
    end
    
  end
  
  Foo.auto_migrate!
  
  before :each do
    @u = Update.immidiate(Foo,:bar,[])
    @w = Worker.new(:name=>"first", :quiet=>true)
  end
  
  it "An unlocked record should lock" do
    @u.lock(@w).should be_true
    @u.locked?.should be_true
    @u.locked_by.should == @w.name
  end
  
  it "A locked record should NOT lock" do
    @u.lock(@w).should be_true
    @u.lock(Worker.new(:quiet=>true)).should be_false
  end
  
  it "A record that failed to lock should not change" do
    @u.lock(@w).should be_true
    @u.lock(Worker.new(:quiet=>true)).should be_false
    @u.locked_by.should == @w.name
  end
  
  it "A record should report as locked if locked by the same worker twice" do
    @u.lock(@w).should be_true
    @u.lock(@w).should be_true
  end
  
  describe "#run_with_lock" do
    
    it "should run an unlocked record" do
      u = Update.immidiate(Foo,:bar,[:arg1,:arg2])
      Foo.should_receive(:bar).with(:arg1,:arg2)
      u.run_with_lock(@w).should be_true
    end
    
    it "should NOT run an already locked record" do
      u = Update.immidiate(Foo,:bar,[:arg1,:arg2])
      u.lock(Worker.new)
      Foo.should_not_receive(:bar)
      u.run_with_lock(@w).should be_nil
    end
    
    it "should return false if the update ran but there was an error" do
      u = Update.immidiate(Foo,:bar,[:arg1,:arg2])
      Foo.should_receive(:bar).with(:arg1,:arg2).and_raise(RuntimeError)
      u.run_with_lock(@w).should be_false
    end
    
  end
  
  it "#clear_locks should lear all locks from a worker"
  
end