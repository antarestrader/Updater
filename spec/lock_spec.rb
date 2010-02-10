require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

require  File.join( File.dirname(__FILE__),  "fooclass" )

describe "Update Locking:" do
  
  
  class Worker
    attr_accessor :pid
    attr_accessor :name
    
    def initialize(options={})
      @quiet = options[:quiet]
      @name = options[:name] || "host:#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"
      @pid = Process.pid
    end
    
    def say(text)
      puts text
      nil
    end
  end    
  
  before :each do
    Foo.all.destroy!
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
   
  it "#clear_locks should clear all locks from a worker" do
    @v = Update.immidiate(Foo,:bar,[:arg1,:arg2])
    @u.lock(@w)
    @v.lock(@w)
    @u.locked?.should be_true
    Update.clear_locks(@w)
    @u.reload.locked?.should be_false
    @v.reload.locked?.should be_false
  end
  
end