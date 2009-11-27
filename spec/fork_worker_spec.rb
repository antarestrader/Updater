require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

def fake_process_status(estat=0)
  stub("Process Status",:pid=>1234,:exit_status=>estat)
end

def fake_iostream
  stub("IOStream").as_null_object
end

describe ForkWorker do
  
  describe "#reap_all_workers" do
    it "should remove workers" do
      Process.should_receive(:waitpid2).with(-1,Process::WNOHANG).twice\
        .and_return([1234,fake_process_status],nil)
      ForkWorker.should_receive(:remove_worker).with(1234).once
      ForkWorker.reap_all_workers
    end
    
    it "should not fail if there are no child processes" do
      Process.should_receive(:waitpid2).with(-1,Process::WNOHANG).once\
        .and_raise(Errno::ECHILD)
      lambda{ForkWorker.reap_all_workers}.should_not raise_error
    end
    
  end
  
  describe "#remove_worker" do
    
    it "should silently ignore missing workers" do
      lambda{ForkWorker.remove_worker(1234)}.should_not raise_error
    end
    
    it "should remove the worker from the set" do
      worker = ForkWorker::WorkerMonitor.new(1,stub("IOStream").as_null_object)
      ForkWorker.instance_variable_set :@workers, {1234=>worker}
      ForkWorker.remove_worker(1234)
      ForkWorker.instance_variable_get(:@workers).should == {}
    end
    
    it "should close the removed workers heartbeat file" do
      ios = mock("IOStream")
      ios.should_receive(:close).and_return(nil)
      worker = ForkWorker::WorkerMonitor.new(1,ios)
      ForkWorker.instance_variable_set :@workers, {1234=>worker}
      ForkWorker.remove_worker(1234)
    end
    
    it "should not fail if the heartbeat file is already closed" do
      ios = mock("IOStream")
      ios.should_receive(:close).and_raise(IOError)
      worker = ForkWorker::WorkerMonitor.new(1,ios)
      ForkWorker.instance_variable_set :@workers, {1234=>worker}
      lambda{ForkWorker.remove_worker(1234)}.should_not raise_error
    end
    
  end
  
  describe "#add_worker" do
    
    it "should add the new worker to the set" do
      Process.stub!(:fork).and_return(1234)
      ForkWorker.add_worker(1)
      ForkWorker.instance_variable_get(:@workers).values.should include(1)
      ForkWorker.instance_variable_get(:@workers).keys.should include(1234)
    end
    
    it "should run a new worker instance in a fork" do
      ForkWorker.instance_variable_set :@workers, {}
      Process.should_receive(:fork).with(no_args()).and_yield.and_return(1234)
      ForkWorker.should_receive(:fork_cleanup).and_return(nil) #
      ForkWorker.should_receive(:new).with(anything(),duck_type(:number,:heartbeat)).and_return(stub("Worker",:run=>nil))
      ForkWorker.add_worker(1)
    end
    
  end
  
  describe "#spawn_missing_workers" do
    
    it "should add a worker with an empty set" do
      ForkWorker.should_receive(:add_worker).with(0)
      ForkWorker.instance_variable_set :@current_workers, 1
      ForkWorker.instance_variable_set :@workers, {}
      ForkWorker.spawn_missing_workers
    end
    
    it "should add a worker when there are fewer then needed" do
      ForkWorker.should_receive(:add_worker).with(1)
      ForkWorker.instance_variable_set :@current_workers, 2
      ForkWorker.instance_variable_set :@workers, {1233=>ForkWorker::WorkerMonitor.new(0,nil)}
      ForkWorker.spawn_missing_workers
    end
    
    it "should add a worker when one has gon missing" do
      ForkWorker.should_receive(:add_worker).with(0)
      ForkWorker.should_receive(:add_worker).with(2)
      ForkWorker.instance_variable_set :@current_workers, 3
      ForkWorker.instance_variable_set :@workers, {1233=>ForkWorker::WorkerMonitor.new(1,nil)}
      ForkWorker.spawn_missing_workers
    end
    
    it "should not add workers if thier are already enough" do
      ForkWorker.should_not_receive(:add_worker)
      ForkWorker.instance_variable_set :@current_workers, 1
      ForkWorker.instance_variable_set :@workers, {1233=>ForkWorker::WorkerMonitor.new(0,nil)}
      ForkWorker.spawn_missing_workers
    end
    
  end
  
  describe "#initial_setup" do
    
    it "should set up a logger when one does not exist" do
      ForkWorker.initial_setup({})
      ForkWorker.logger.should_not be_nil
      %w{debug info warn error fatal}.each do |n|
        ForkWorker.logger.should respond_to(n.to_sym)
      end
    end
    
    it "should set workers set to empty" do
      ForkWorker.initial_setup({})
      ForkWorker.instance_variable_get(:@workers).should be_empty
    end
    
    it "should create a pipe for children" do
      pipe = ForkWorker.instance_variable_get(:@pipe)
      pipe.length.should ==2
      pipe.each {|io| io.should be_an IO}
    end
    
  end
  
  describe "#handle_signal_queue" do
    
    before :each do
      ForkWorker.initial_setup({})
    end
    
    [:QUIT, :INT].each do |sig|
      it "it should exicute a graceful shutdown on #{sig.to_s}" do
        ForkWorker.should_receive(:stop).with(true)
        ForkWorker.stub!(:awaken_master, true)
        
        ForkWorker.queue_signal(sig)
        ForkWorker.handle_signal_queue.should be_false
      end
    end
    
    it "it should exicute a rapid shutdown on TERM" do
      ForkWorker.should_receive(:stop).with(false)
      ForkWorker.stub!(:awaken_master, true)
      
      ForkWorker.queue_signal(:TERM)
      ForkWorker.handle_signal_queue.should be_false
    end
    
    [:USR2, :DATA].each do |sig|
      it "should write to the pipe on #{sig.to_s}" do
        ForkWorker.queue_signal(sig)
        ForkWorker.handle_signal_queue.should be_true
        pipe = ForkWorker.instance_variable_get(:@pipe)
        lambda{pipe.first.read(1)}.should_not raise_error
      end
    end
    
    it "should do maintance when the queue is empty" do
      ForkWorker.should_receive(:murder_lazy_workers)
      ForkWorker.should_receive(:maintain_worker_count)
      ForkWorker.should_receive(:master_sleep)
      
      ForkWorker.handle_signal_queue.should be_true      
    end
    
    it "should increase max_workers on TTIN and decrease on TTOU" do
      ForkWorker.queue_signal(:TTIN)
      ForkWorker.handle_signal_queue.should be_true
      ForkWorker.instance_variable_get(:@max_workers).should == 2
      
      ForkWorker.queue_signal(:TTOU)
      ForkWorker.handle_signal_queue.should be_true
      ForkWorker.instance_variable_get(:@max_workers).should == 1
    end
    
    it "should never allow max_workers to be less then 1" do
      ForkWorker.queue_signal(:TTOU)
      ForkWorker.handle_signal_queue.should be_true
      ForkWorker.instance_variable_get(:@max_workers).should == 1
    end
  
  end

  describe "Master loop control" do
    
    before(:each) do
      ForkWorker.initial_setup({})
    end
  
    describe "#master_sleep" do
      
      it "should return to run maintance if there is no signal" do
        IO.should_receive(:select).and_return(nil)
        ForkWorker.master_sleep.should be_nil
        ForkWorker.instance_variable_get(:@signal_queue).should be_empty
      end
      
      it "should return if there is data on self_pipe" do
        self_pipe = ForkWorker.instance_variable_get(:@self_pipe)
        IO.should_receive(:select).and_return([[self_pipe.first],[],[]])
        ForkWorker.master_sleep.should be_nil
        ForkWorker.instance_variable_get(:@signal_queue).should be_empty
      end
      
      it "should also add ':DATA' to queue when a stream other then self_pipe is ready." do
        pending "Testing Error  stream not raising error?"
        stream = stub('Extern IO').should_receive(:read_nonblock).and_raise(Errno::EAGAIN)
        IO.should_receive(:select).and_return([[stream],[],[]])
        ForkWorker.master_sleep.should be_nil
        ForkWorker.instance_variable_get(:@signal_queue).should include(:DATA)
      end
      
    end

  end
  
  
  [true,false].each do |graceful|
    
    describe "#stop(#{graceful})" do
      before :each do
        ForkWorker.initial_setup({})
      end
      
      describe "with no workers" do
        it "should not fail" do
          [true,false].each {|graceful| lambda{ForkWorker.stop(graceful)}.should_not raise_error}
        end
        
        it "should not signal any workers" do
          ForkWorker.should_not_receive(:signal_worker)
          [true,false].each {|graceful| ForkWorker.stop(graceful)}
        end
      end
      
      describe "with workers" do
        
        before :each do
          ForkWorker.instance_variable_set :@workers, 
            {
              1233=>ForkWorker::WorkerMonitor.new(0,fake_iostream),
              1234=>ForkWorker::WorkerMonitor.new(0,fake_iostream)
            }
          Process.stub!(:waitpid2) do |_1,_2|
            [ ForkWorker.instance_variable_get(:@workers).keys.first,
              fake_process_status
            ]
          end
        end
        
        it "should signals each worker to end" do
          ForkWorker.instance_variable_get(:@workers).keys.each do |pid|
            ForkWorker.should_receive(:signal_worker).with(graceful ? :QUIT : :TERM,pid)
          end
          ForkWorker.stop(graceful)
        end
        
        it "should not kill workers that successfully quit" do
          ForkWorker.should_not_receive(:signal_worker).with(:KILL,anything())
          ForkWorker.stop(graceful)
        end
        
      end
      
    end
    
  end
  
end