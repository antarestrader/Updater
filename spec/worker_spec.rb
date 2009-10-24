require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

describe Worker do
  
  it "should not print anything when quiet" do
    w = Worker.new :quiet=>true
    out = StringIO.new
    $stdout = out
    w.say "hello world"
    $stdout = STDOUT
    out.string.should be_empty
  end
  
  it "should have a name" do
    Worker.new.name.should be_a String
  end
  
  describe "loop thread control:" do
    
    class Foo
      include DataMapper::Resource
      
      property :id, Serial
      property :name, String
      
      def bar(*args)
        Foo.bar(:instance,*args)
      end
      
    end
    
    Foo.auto_migrate!
    
    specify "The loop should run when the worker is started" do
      pending
      worker = Worker.new(:quiet=>true, :name=>"testing")
      Update.should_receive(:work_off).with(worker).once.and_return(nil)
      t = Thread.new do
        worker.start
      end
      t.run
      worker.stop
      t.kill unless t.join(0.1) #you've got 0.1 seconds to finish or die
    end
    
    specify "The loop should run with USR1 signal" do
      pending
      t = Thread.new do
        worker.start
      end
    end
    
  end
  
end

describe "working off jobs:" do
  
  class Foo
    include DataMapper::Resource
    
    property :id, Serial
    property :name, String
    
    def bar(*args)
      Foo.bar(:instance,*args)
    end
    
  end
  
  describe "Update#work_off" do
    
    before :each do
      Update.all.destroy!
    end 
  
    it "should run and immidiate job"do
      u = Update.immidiate(Foo,:bar,[:arg1,:arg2])
      Foo.should_receive(:bar).with(:arg1,:arg2)
      Update.work_off(Worker.new)
    end
    
    it "should aviod conflicts among mutiple workers" do
      u1 = Update.immidiate(Foo,:bar,[:arg1])
      u2 = Update.immidiate(Foo,:baz,[:arg2])
      Foo.should_receive(:bar).with(:arg1)
      Foo.should_receive(:baz).with(:arg2)
      Update.work_off(Worker.new(:name=>"first", :quiet=>true))
      Update.work_off(Worker.new(:name=>"second", :quiet=>true))
    end
    
    it "should return 0 if there are more jobs waiting" do
      u1 = Update.immidiate(Foo,:bar,[:arg1])
      u2 = Update.immidiate(Foo,:baz,[:arg2])
      Update.work_off(Worker.new(:name=>"first", :quiet=>true)).should == 0
    end
    
    it "should return the number of seconds till the next job if there are no jobs to be run" do
      Timecop.freeze(Time.now)
      u1 = Update.at(Time.now + 30, Foo,:bar,[:arg1])
      Update.at(Time.now + 35, Foo,:bar,[:arg1])
      Update.at(Time.now + 1000, Foo,:bar,[:arg1])
      Update.work_off(Worker.new(:name=>"first", :quiet=>true)).should == 30
    end
    
    it "should return nil if the job queue is empty" do
      u1 = Update.immidiate(Foo,:bar,[:arg1])
      Update.work_off(Worker.new(:name=>"first", :quiet=>true)).should be_nil
    end
    
  end
  
end