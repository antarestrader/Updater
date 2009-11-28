require 'updater/util'
#The content of this file is based on code from Unicorn by 

module Updater

  #This class repeatedly searches the database for active jobs and runs them
  class ForkWorker
    class WorkerMonitor < Struct.new(:number, :heartbeat)
      
      def ==(other_number)
        self.number == other_number
      end
    end
    
    class <<self
      QUEUE_SIGS = [:QUIT, :INT, :TERM, :USR1, :USR2, :HUP,
                   :TTIN, :TTOU ]
      
      attr_accessor :logger
      attr_reader :timeout, :pipe
      
      def initial_setup(options)
        unless logger
          require 'logger'
          @logger = Logger.new(STDOUT)
          @logger.level = Logger::WARN
        end
        logger.info "***Setting Up Master Process***"
        
        @max_workers = options[:workers] || 1
        logger.info "Max Workers set to #{@max_workers}"
        @timeout = options[:timout] || 60
        logger.info "Timeout set to #{@timeout} sec."
        @current_workers = 1
        @workers = {} #key is pid value is worker class
        
        # Used to wakeup master process 
        if @self_pipe !=nil
          @self_pipe.each {|io| io.close}
        end
        @self_pipe = IO.pipe
        @wakeup_set = [@self_pipe.first]
        @wakeup_set += [options[:sockets]].flatten.compact
        
        #Communicate with Workers
        if @pipe != nil
          @pipe.each {|io| io.close}
        end
        @pipe = IO.pipe
        
        @signal_queue = []
        
        
      end
      
      def handle_signal_queue
        logger.debug { "Handeling Signal Queue: queue first = #{@signal_queue.first}" }
        case @signal_queue.shift
          when nil #routeen maintance
            logger.debug "Running Routeen Maintance"
            murder_lazy_workers
            antisipate_workload
            maintain_worker_count
            master_sleep
            true
          when :QUIT, :INT
            stop(true)
            false
          when :TERM
            stop(false)
            false
          when :USR2, :DATA #wake up a child and get to work
            @pipe.last.write_nonblock('.')
            true
          when :TTIN
            @max_workers += 1
          when :TTOU
            (@max_workers -= 1) < 1 and @max_workers = 1
            true
          else
            :noop
        end
      end
      
      # Options:
      # * :workers : the maximum number of worker threads
      # * :timeout : how long can a worker be inactive before being killed
      # * :sockets: 0 or more IO objects that should wake up master to alert it that new data is availible
      
      def start(stream,options = {})
        initial_setup(options) #need this for logger
        logger.info "*** Starting Master Process***"
        @stream = stream
        logger.info "* Adding the first round of workers *"
        maintain_worker_count
        QUEUE_SIGS.each { |sig| trap_deferred(sig) }
        trap(:CHLD) { |sig_nr| awaken_master }
        logger.info "** Signal Traps Ready **"
        logger.info "** master process ready  **"
        begin
          continue = true
          while continue do
            logger.debug "Master Process Awake" 
            reap_all_workers
            continue = handle_signal_queue
          end
        rescue Errno::EINTR
          retry
        rescue Object => e
          logger.error "Unhandled master loop exception #{e.inspect}."
          logger.error e.backtrace.join("\n")
          retry
        end
        stop # gracefully shutdown all workers on our way out
        logger.info "master process Exiting"
      end
      
      def stop(graceful = true)
        limit = Time.now + 30
        signal_each_worker(graceful ? :QUIT : :TERM)
        until @workers.empty? || Time.now > limit
          sleep(0.1)
          reap_all_workers
        end
        signal_each_worker(:KILL)
      end
      
      def master_sleep
        begin
          logger.debug { "Sleeping for #{2*@timeout}" }
          ready, _1, _2 = IO.select(@wakeup_set, nil, nil, 2*@timeout)
          return unless ready && ready.first #just wakeup and run maintance
          @signal_queue << :DATA unless ready.first == @self_pipe.first #somebody wants our attention
          loop {ready.first.read_nonblock(16 * 1024)}
        rescue Errno::EAGAIN, Errno::EINTR
        end
      end
      
      def awaken_master
        begin
          @self_pipe.last.write_nonblock('.') # wakeup master process from select
        rescue Errno::EAGAIN, Errno::EINTR
          # pipe is full, master should wake up anyways
          retry
        end
      end
      
      def queue_signal(signal)
        if @signal_queue.size < 7
          @signal_queue << signal
          awaken_master
        else
          logger.error "ignoring SIG#{signal}, queue=#{SIG_QUEUE.inspect}"
        end
      end
      
      def trap_deferred(signal)
        trap(signal) do |sig|
          queue_signal(signal)
        end
      end
      
      # this method determins how many workers should exist based on the known future load
      # and sets @current_workers accordingly
      def antisipate_workload
        
      end
      
      def maintain_worker_count
        (off = @workers.size - @current_workers) == 0 and return
        off < 0 and return spawn_missing_workers
        @workers.dup.each_pair { |wpid,w|
          w.number >= @current_workers and signal_worker(:QUIT, wpid) rescue nil
        }
      end
      
      def spawn_missing_workers
        (0...@current_workers).each do |worker_number|
          @workers.values.include?(worker_number) and next
          add_worker(worker_number)
        end
      end
      
      def add_worker(worker_number)
        worker = WorkerMonitor.new(worker_number,Updater::Util.tempio)
        pid = Process.fork do
          fork_cleanup
          self.new(@pipe,worker).run
        end
        @workers[pid] = worker
        logger.info "Added Worker #{worker.number}: pid=>#{pid}"
      end
      
      def fork_cleanup
        if @self_pipe !=nil
          @self_pipe.each {|io| io.close}
        end
        @workers = nil
        @worker_set = nil
        @signal_queue = nil
      end
      
      def signal_each_worker(signal)
        @workers.keys.each { |wpid| signal_worker(signal, wpid)}
      end
      
      def signal_worker(signal, wpid)
        Process.kill(signal,wpid)
      rescue Errno::ESRCH
        remove_worker(wpid)
      end
      
      def murder_lazy_workers
        diff = stat = nil
        @workers.dup.each_pair do |wpid, worker|
          stat = begin
            worker.heartbeat.stat
          rescue => e
            logger.warn "worker=#{worker.number} PID:#{wpid} stat error: #{e.inspect}"
            signal_worker(:QUIT, wpid)
            next
          end
          (diff = (Time.now - stat.ctime)) <= @timeout and next
          logger.error "worker=#{worker.nr} PID:#{wpid} timeout " \
                       "(#{diff}s > #{@timeout}s), killing"
          signal_worker(:KILL, wpid) # take no prisoners for timeout violations
        end
      end
      
      def remove_worker(wpid)
        worker = @workers.delete(wpid) and worker.heartbeat.close rescue nil
      end
      
      def reap_all_workers
        loop do
          wpid, status = Process.waitpid2(-1, Process::WNOHANG)
          wpid or break
          remove_worker(wpid)
        end
      rescue Errno::ECHILD
      end
    
    end
    
    def initialize(pipe,worker)
      @stream = pipe.first
      pipe.last.close
      @heartbeat = worker.heartbeat
      @number = worker.number
      @timeout = self.class.timeout
      @m = 0 #uesd for heartbeat
    end
    
    #loop "forever" working off jobs from the queue
    def run
      heartbeat
      @continue = true
      #setup_traps
      while @continue do
        heartbeat
        begin
          delay = Update.work_off(self)
          heartbeat
          wait_for(delay)
        rescue Exception=> e
          say "Caught exception in Job Loop"
          raise e
          sleep 0.1
          retry
        end
      end
      Update.clear_locks(self)
    end
    
    def logger
      nil
    end
    
    def say(text)
      puts text unless @quiet
      logger.info text if logger      
    end
    
    def name
      "Fork Worker #{@number}"
    end
    
    def wait_for(delay)
      if delay <= 0 #more jobs are immidiatly availible
        smoke_pipe(@stream)
        return
      end
      
      #need to wait for another job
      t = Time.now + delay
      while Time.now < t
        delay = [@timeout,Time.now - t].min
        wakeup,_1,_2 = select([@stream],nil,nil,delay)
        heartbeat
        if wakeup
          return if smoke_pipe(wakeup.first)
        end
      end
    end
    
    # tries to pull a single charictor from the pipe (representing accepting one new job)
    # returns true if it succeeds, false otherwise
    def smoke_pipe(pipe)
      pipe.first.read_nonblock(1) #each char in the string represents a new job 
      true
    rescue Errno::EAGAIN, Errno::EINTR
      false
    end
    
    def heartbeat
      @heartbeat.chmod(@m = 0 == @m ? 1 : 0)
    end
  end
  
end