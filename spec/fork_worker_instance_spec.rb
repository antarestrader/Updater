require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

describe "Fork Worker Instance" do
  
  before :each do
    @worker = ForkWorker::WorkerMonitor.new(1,Updater::Util.tempio)
    @w = ForkWorker.new(IO.pipe,@worker)
  end
  
  it "should have a heartbeat" do
    @w.instance_variable_set(:@continue, true) #otherwise heartbeat is skipped 
    mode = @worker.heartbeat.stat.mode
    @w.heartbeat
    @worker.heartbeat.stat.mode.should_not == mode
  end
  
  describe "#smoke_pipe" do
    
    before :each do
      @pipe = IO.pipe
    end
  
    it "should remove exactly 1 char from a pipe" do
      @pipe.last.write '..'
      @w.smoke_pipe(@pipe.first).should be_true
      @pipe.first.read_nonblock(2).should == '.'
    end
    
    it "should not raise errors or block on empty pipes" do
      lambda { @w.smoke_pipe(@pipe.first) }.should_not raise_error
    end
    
  end
  
  describe "#wait_for" do
    
    it "should have specs"
    
    describe "when there are pending jobs" do
      
      it "should NOT wait for a signal"
      
      it "should smoke the pipe"
      
    end
    
    it "should wake as soon as a new job signal is placed on the pipe"
    
    
    it "should run the heartbeat every 'timeout' seconds"
    
  end
  
end