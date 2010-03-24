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
    
    #######
    # BEGIN Class Methods
    #######
    
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
        logger.warn "***Setting Up Master Process***"
        logger.warn "    Pid = #{Process.pid}"
        @max_workers = options[:workers] || 3
        logger.info "Max Workers set to #{@max_workers}"
        @timeout = options[:timeout] || 60
        logger.info "Timeout set to #{@timeout} sec."
        @current_workers = 1 #we will actually add this worker the first time through the master loop
        @workers = {} #key is pid value is worker class
        @uptime = Time.now
        @downtime = Time.now
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
            logger.warn "Maximum workers: #{@max_workers}"
          when :TTOU
            (@max_workers -= 1) < 1 and @max_workers = 1
            logger.warn "Maximum workers: #{@max_workers}"
            true
          else
            :noop
        end
      end
      
      # Options:
      # * :workers : the maximum number of worker threads
      # * :timeout : how long can a worker be inactive before being killed
      # * :sockets: 0 or more IO objects that should wake up master to alert it that new data is availible
      
      def start(options = {})
        initial_setup(options) #need this for logger
        logger.info "*** Starting Master Process***"
        logger.info "* Adding the first round of workers *"
        maintain_worker_count
        QUEUE_SIGS.each { |sig| trap_deferred(sig) }
        trap(:CHLD) { |sig_nr| awaken_master }
        logger.info "** Signal Traps Ready **"
        logger.info "** master process ready  **"
        begin
          error_count = 0
          continue = true
          while continue do
            logger.debug "Master Process Awake" 
            reap_all_workers
            continue = handle_signal_queue
            error_count = 0
          end
        rescue Errno::EINTR
          retry
        rescue Object => e
          logger.error "Unhandled master loop exception #{e.inspect}. (#{error_count})"
          logger.error e.backtrace.join("\n")
          error_count += 1
          sleep 10 and retry unless error_count > 10
          logger.fatal "10 consecutive errors! Abandoning Master process"
        end
        stop # gracefully shutdown all workers on our way out
        logger.warn "-=-=-=- master process Exiting -=-=-=-\n\n"
      end
      
      def stop(graceful = true)
        trap(:USR2,"IGNORE")
        [:INT,:TERM].each {|signal| trap(signal,"DEFAULT") }
        puts "Quitting. I need 30 seconds to stop my workers..." unless @workers.empty?
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
          timeout = calc_timeout
          logger.debug { "Sleeping for #{timeout}" }
          ready, _1, _2 = IO.select(@wakeup_set, nil, nil, timeout)
          return unless ready && ready.first #timeout hit,  just wakeup and run maintance
          add_connection(ready.first) and return if ready.first.respond_to?(:accept) #open a new incomming connection 
          @signal_queue << :DATA unless ready.first == @self_pipe.first
          loop {ready.first.read_nonblock(16 * 1024)}
        rescue EOFError #somebody closed thier connection
          logger.info "closed socket connection"
          @wakeup_set.delete ready.first
          ready.first.close
        rescue Errno::EAGAIN, Errno::EINTR
        end
      end
      
      def add_connection(server)
        @wakeup_set << server.accept_nonblock
        logger.info "opened socket connection: [#{@wakeup_set.last.addr.join(', ')}]"
      rescue Errno::EAGAIN, Errno::EINTR
      end
      
      def calc_timeout
        Time.now - [@uptime, @downtime].max < @timeout ? @timeout / 8 : 2*@timeout
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
          logger.error "ignoring SIG#{signal}, queue=#{@signal_queue.inspect}"
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
        load = Update.load
        antisipated = Update.future(2*@timeout)
        if (load > @current_workers && 
            @current_workers < @max_workers && 
            (Time.now - (@downtime || 0)).to_i > 5 &&
            (Time.now-(@uptime||0.0)).to_i > 1)
          @current_workers += 1
          @uptime = Time.now
        end
        
        if  (load + antisipated + 1 < @current_workers &&
             (Time.now-(@uptime||0.0)).to_i > 60 &&
             (Time.now - (@downtime || 0)).to_i > 5)
          @current_workers -= 1
          @downtime = Time.now
        end
        
        if @current_workers > @max_workers
          @current_workers = @max_workers
        end
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
        Update.orm.before_fork
        pid = Process.fork do
          fork_cleanup
          self.new(@pipe,worker).run
        end
        @workers[pid] = worker
        logger.info "Added Worker #{worker.number}: pid=>#{pid}"
      end
      
      def fork_cleanup
        QUEUE_SIGS.each { |signal| trap(signal,"IGNORE") }
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
          logger.error "worker=#{worker.number} PID:#{wpid} timeout " \
                       "(#{diff}s > #{@timeout}s), killing"
          signal_worker(:KILL, wpid) # take no prisoners for timeout violations
        end
      end
      
      def remove_worker(wpid)
        worker = @workers.delete(wpid) and worker.heartbeat.close rescue nil
        logger.debug { "removing dead worker #{worker.number}" }
      end
      
      def reap_all_workers
        loop do
          wpid, status = Process.waitpid2(-1, Process::WNOHANG)
          wpid or break
          remove_worker(wpid)
        end
      rescue Errno::ECHILD
      end
      
      #A convinient method for testing. It builds a dummy workier without forking or regertering it.
      def build
        new(@pipe,WorkerMonitor.new(-1,Updater::Util.tempio))
      end
    
    end #class << self

    #
    #
    ##################################################
    # BEGIN Instacne methods
    ##################################################
    #
    #
    #
    
    attr_accessor :logger
    attr_reader :number
    
    def initialize(pipe,worker)
      @stream = pipe.first
      @pipe = pipe  #keep this so signals will wake things up
      @heartbeat = worker.heartbeat
      @number = worker.number
      @timeout = self.class.timeout
      @logger = self.class.logger
      @m = 0 #uesd for heartbeat
    end
    
    #loop "forever" working off jobs from the queue
    def run
      @continue = true
      heartbeat
      trap(:QUIT) do 
        say "#{name} caught QUIT signal.  Dieing gracefully"
        @continue = false 
        @pipe.last.write '.'
        trap(:QUIT,"IGNORE")
      end
      trap(:TERM) { Update.clear_locks(self); Process.exit!(0) }
      logger.info "#{name} is on-line"
      while @continue do
        heartbeat
        begin
          delay = Update.work_off(self)
          heartbeat
          wait_for(delay) if @continue
        rescue Exception=> e
          say "Caught exception in Job Loop"
          say e.inspect
          say "\n||=========\n|| Backtrace\n|| " + e.backtrace.join("\n|| ") + "\n||========="
          Update.clear_locks(self)
          exit; #die and be replaced by the master process
        end
      end
      Update.clear_locks(self)
    end
    
    def say(text)
      puts text unless @quiet || logger
      logger.info text if logger      
    end
    
    #we need this because logger may be set to nil
    def debug(text = nil)
      text = yield if block_given? && logger && logger.level == 0
      logger.debug text if logger      
    end
    
    def name
      "Fork Worker #{@number}"
    end
    
    # Let's Talk.  This function was refactored out of #run because it is the most complex piece of functionality
    # in the loop and needed to be tested.  #run is difficult to test because it never returns.  There is a great
    # deal of straitagity here.  This function ultimate job is to suspend the worker process for as long as possible.
    # In doing so it saves the system resources.  Waiting too long will cause catistrophic, cascading failure under
    # even moderate load, while not waiting long enough will waist system resources under light load, reducing
    # the ability to use the system for other things.
    #
    # There are a number of factors that determin the amount of time to wait.  The simplest is this: if there are
    # still jobs in the queue that can be run then this function needs to be as close to a NOOP as possible. Every
    # delay is inviting more jobs to pile up before they can be run.  The Job running code returns the number of
    # seconds until the next job is availible.  When it retruns 0 the system is under active load and jobs need to
    # be worked without delay.
    #
    # On the other hand when the next job is some non-negitive number of seconds away the ideal behavior
    # would be to wait until it is ready then run the next job the wake and run it.  There are two difficulties here
    # the first is the need to let the master process know that the worker is alive and has not hung.  We use a 
    # heartbeat file discriptor which we periodically change ctimes on by changing its access mode.  This is
    # modeled the technique used in the Unicorn web server.  Our difficult is that we must be prepaired for a 
    # much less consistant load then a web server.  Within a single application there may be periods where jobs
    # pile up and others where there is a compleatly empty queue for hours or days.  There is also the issue of 
    # how long a job may take to run.  Jobs should generally be kept on the order of +timeout+ seconds.
    # a Job that is likely to significantly exceed that will need to be broken up into smaller pieces.  This 
    # function on the other hand deals with no jobs being present.  It must wake up the worker every timeout
    # seconds inorder to exicute +heartbeat+ and keep it's self from being killed.
    #
    # The other consideration is a new job coming in while all workers are asleep.  When this happens, the
    # Master process will write to the shared pipe and one of the workers will be awoken by the system.  To
    # minimize the number of queue hits, it is necessary to try to remove a char representing a new job from
    # the pipe every time one is present.  The +smoke_pipe+ method handles this by attempting to remove a 
    # charactor from the pipe when it is called.
    def wait_for(delay)
      return unless @continue
      delay ||= 356*24*60*60 #delay will be nil if there are no jobs.  Wait a really long time in that case.
      if delay <= 0 #more jobs are immidiatly availible
        smoke_pipe(@stream) 
        return
      end
      
      #need to wait for another job
      t = Time.now + delay
      while Time.now < t && @continue
        delay = [@timeout/2,t-Time.now].min
        debug "No Jobs; #{name} sleeping for #{delay}:  [#{@timeout/2},#{t - Time.now}].min"
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
      debug { "#{name} smoking pipe (#{ts})" }
      pipe.read_nonblock(1) #each char in the string represents a new job 
      debug { "   done smoking (#{ts})" }
      true
    rescue Errno::EAGAIN, Errno::EINTR
      false
    end
    
    def heartbeat
      return unless @continue
      debug "Heartbeat for worker #{name}"
      @heartbeat.chmod(@m = 0 == @m ? 1 : 0)
    end
    
    def ts
      Time.now.strftime("%H:%M:%S")
    end
  end
  
end