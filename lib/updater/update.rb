module Updater
  class TargetMissingError < StandardError
  end

  #The basic class that drives Updater. See Readme for usage information. 
  class Update
    # Contains the Error class after an error is caught in +run+. Not stored to the database
    attr_reader :error
    
    # Contains the underlying ORM instance (eg. ORM::Datamapper or ORM Mongo)
    attr_reader :orm
    
    # In order to reduce the proliferation of chained jobs in the queue,
    # jobs chain request are allowed a params value that will pass 
    # specific values to a chained method.  When a chained instance is 
    # created, the job processor will set this value.  It will then be sent
    # to the target method in plance of '__param__'.  See #sub_args
    attr_accessor :params
    
    #Run the action on this traget compleating any chained actions
    def run(job=nil)
      ret = true #put return in scope
      begin
        t = target 
        final_args = sub_args(job,@orm.method_args)
        t.send(@orm.method.to_sym,*final_args)
      rescue => e
        @error = e
        run_chain :failure
        ret = false
      ensure
        run_chain :success if ret
        run_chain :ensure
        begin
          @orm.destroy unless @orm.persistant
        rescue StandardError => e
          raise e unless e.class.to_s =~ /Connection/
          sleep 0.1
          retry
        end
      end
      ret
    end
    
    #see if this method was intended for the underlying ORM layer.
    def method_missing(method, *args)
      @orm.send(method,*args)
    end
    
    # Determins and if necessary find/creates the target for this instance.
    # 
    # Warning: This value is intentionally NOT memoized.  For instance type targets, it will result in a call to the datastore 
    # (or the recreation of an object) on EACH invocation.  Methods that need to refer to the target more then once should
    # take care to store this value locally after initial retreavel.
    def target
      target = @orm.finder.nil? ? @orm.target : @orm.target.send(@orm.finder,@orm.finder_args)
      raise TargetMissingError, "Target missing --Class:'#{@orm.target}' Finder:'#{@orm.finder}', Args:'#{@orm.finder_args.inspect}'" unless target
      target
    end
    
    # orm_inst must be set to an instacne of the class Update.orm
    def initialize(orm_inst)
      raise ArgumentError if orm_inst.nil? || !orm_inst.kind_of?(self.class.orm)
      @orm = orm_inst
    end
    
    #Jobs may be named to make them easier to find
    def name=(n)
      @orm.name=n
    end
    
    #Jobs may be named to make them easier to find 
    def name
      @orm.name
    end
    
    #This is the appropriate value to use for a chanable field value
    def id
      @orm.id
    end
    
    def ==(other)
      id = other.id
    end
    
    # If this is true, the job will NOT be removed after it is run.  This is usually true for chained Jobs.
    def persistant?
      @orm.persistant
    end
    
    def inspect
      "#<Updater::Update target=#{target.inspect} time=#{orm.time}>"
    rescue TargetMissingError
      "#<Updater::Update target=<missing> time=#{orm.time}>"
    end
    
  private
    
    # == Use and Purpose
    # Takes a previous job and the original array of arguments form the data store.
    # It replaced three special values with meta information from Updater.  This is
    # done to allow chained jobs to respond to specific conditions in the originating
    # job.
    #
    # ==Substitutions
    # The following strings are replaced with meta information from the calling job
    # as described below:
    #
    # * '__job__': replaced with the instance of Updater::Update that chained into
    #   this job.  If the job failed (that is raised and error while being run), this
    #   instance will contain an error field with that error.
    # * '__params__': this is an optional field of a chain instance.  It allows the 
    #   chaining job to set specific options for the chained job to use. For example
    #   a chained job that reschedules the the original job might take an option 
    #   defining how frequently the job is rescheduled.  This would be passed in 
    #   the params field.  (See example in Updater::Chained -- Pending!)
    # * '__self__':  this is simply set to the instance of Updater::Update that is 
    #   calling the method.  This might be useful for both chained and original
    #   jobs that find a need to manipulate of inspect that job that called them.
    #   Without this field, it would be impossible for a method to consistantly 
    #   determin wether it had been run from a background job or invoked
    #   direclty by the app.
    def sub_args(job,a)
      a.map do |e| 
        begin
          case e.to_s
            when '__job__'
              job
            when '__params__'
              @params
            when '__self__'
              self
            else
              e
          end
        # For the unfortunate case where e doesn't handle to_s nicely.
        # On the other hand I dare someone to find something that can be marshaled,
        # but doesn't do #to_s.
        rescue NoMethodError=>err
          raise err unless err.message =~ /\`to_s\'/
          e
        end #begin
      end# map
    end #def
    
    # Invoked by the runner with the name of a chain (:success, :failure, :ensure),
    # this method takes each chained job and runs it to completion. (Depth First Search of the chain tree)
    def run_chain(name)
      chains = @orm.send(name)
      return unless chains
      chains.each do |job|
        job.run(self)
      end
    rescue NameError 
      # There have been a number of bugs caused by the @orm instance not being what was expected when
      # the ORM layer returned a chain.  This error if produced will propigat to the worker where it is caught
      # and logged, but to prevent a complete crash of the system, it is then ignored and the next job is run.
      # This is here to help catch and debug this type of error in ORM layers, particularly 3rd party ORMs.
      self.class.logger.error "Something is wrong with the ORM value in a chained call \n From (%s:%s):\n%s" % [__FILE__,__LINE__,@orm.inspect]
      raise
    end
    
    class << self
      
      # This attribute must be set to some ORM that will persist the data.  The value is normally set 
      # using one of the methods in Updater::Setup.
      attr_accessor :orm
      
      # This is the application level default method to call on a class in order to find/create a target 
      # instance. (e.g find, get, find_one, etc...).  In most circumstances the ORM layer defines an 
      # appropriate default and this does not need to be explcitly set.  
      #
      # MongoDB is one significant exception to this rule.  The Updater Mongo ORM layer uses the
      # 10gen MongoDB dirver directly without an ORM such as Mongoid or Mongo_Mapper.  If the
      # application uses one of thes ORMs #finder_method and #finder_id should be explicitly set.
      attr_accessor :finder_method
      
      # This is the application level default method to call on an instance type target.  It  should 
      # return a value to be passed to the #finder_method (above) inorder to retrieve the instance
      # from the datastore.  (eg. id) In most circumstances the ORM layer defines an 
      # appropriate default and this does not need to be explcitly set.  
      #
      # MongoDB is one significant exception to this rule.  The Updater Mongo ORM layer uses the
      # 10gen MongoDB dirver directly without an ORM such as Mongoid or Mongo_Mapper.  If the
      # application uses ond of thes ORMs #finder_method and #finder_id should be explicitly set.
      attr_accessor :finder_id
      
      
      #remove once Bug is discovered
      def orm=(input)
        raise ArgumentError, "Must set ORM to and appropriate class" unless input.kind_of? Class
        @orm = input
      end
      
      # This is an open IO socket that will be writen to when a job is scheduled. If it is unset
      # then @pid is signaled instead.
      attr_accessor :socket
      
      # Instance of a conforming logger.  This will be created if it is not explicitly set.
      attr_writer :logger
      
      # Returns the logger instance.  If it has not been set, a new Logger will be created pointing to STDOUT
      def logger
        @logger ||= Logger.new(STDOUT)
      end
      
      #Gets a single job form the queue, locks and runs it.  it returns the number of second
      #Until the next job is scheduled, or 0 is there are more current jobs, or nil if there 
      #are no jobs scheduled.
      def work_off(worker)
        inst = @orm.lock_next(worker)
        if inst
          worker.logger.debug "  running job #{inst.id}" 
          new(inst).run
        else
          worker.logger.debug "  could not find a ready job in the datastore" 
        end
        @orm.queue_time
      ensure
        clear_locks(worker)
      end
      
      #Ensure that a worker no longer holds any locks.
      def clear_locks(worker); @orm.clear_locks(worker); end
      
      # Request that the target be sent the method with args at the given time.
      #
      # == Parameters
      # time <Integer | Object responding to to_i>,  by default the number of seconds sence the epoch.  
      #What 'time'  references  can be set by sending the a substitute class to the time= method.
      #
      # target  <Class | instance> .  If target is a class then 'method' will be sent to that class (unless the 
      # finder option is used.  Otherwise, the target will be assumed to be the result of 
      # (target.class).get(target.id).   (note: The ORM can/should override #get and #id with the proper
      # methods for it's storage model.) The finder method (:get by default) and the finder_args 
      # (target.id by default) can be set in the options.  A ORM (eg DataMapper) instance passed as the target
      # will "just work."  Any object can be found in this mannor is known as a 'conforming instance'.  TODO:
      # make ORM finder and id constants overridable for times when one ORM is used for Updater and another
      # is used by the model classes.
      # 
      # method <Symbol>.  The method that will be sent to the calculated target.
      #
      # args <Array> a list of arguments to be sent to with the method call.  Note: 'args' must be seirialiable
      # with Marshal.dump.  The special values '__job__', '__params__', and '__self__' are replaced they are found 
      # in this list.  Defaults to [].  (note: the #to_s method will be called on all args before variable substitution
      # any arg that responds with one of the special values will be replaced as noted above. E.g :__job__ .  If 
      # something is silly enough to respond to to_s with a non-pure method you *will* have problems. 
      # NoMethodError is caught and handled gracefully)
      #
      # options <Hash>  Addational options that will be used to configure the request.  see Options 
      # section below.
      #
      # == Options
      #
      # :finder <Symbol> This method will be sent to the stored target class (either target or target.class) 
      # inorder to extract the instance on which to preform the request.  By default :get is used.  For
      # example to use on an ActiveRecord class 
      #    :finder=>:find
      #
      # :finder_args <Array> | <Object>.  This is passed to the finder function.  By default it is 
      # target.id.  Note that by setting :finder_args you will force Updater to calculate in instance
      # as the computed target even if you pass a Class as the target.
      #
      # :name <String> A string sent by the requesting class to identify the request.  'name' must be 
      # unique for a given computed target.  Names cannot be used effectivally when a Class has non-
      # conforming instances as there is no way predict the results of a finder call.  'name' can be used
      # in conjunction with the +for+ method to manipulate requests effecting an object or class after
      # they are set.  See +for+ for examples
      #
      # :failure, :success,:ensure <Updater::Update instance> an other request to be run when the request compleste.  Usually these
      # valuses will be created with the +chained+ method.  
      # As an alternative a Hash (OrderedHash in ruby 1.8) with keys of Updater::Update instances and
      # values of Hash may be used.  The hash will be substituted for the '__param__' argument if/when the chained method is called.
      # 
      # :persistant <true|false> if true the object will not be destroyed after the completion of its run.  By default
      # this is false except when time is nil.
      #
      # ===Note:
      # 
      # Unless finder_args is passed, a non-class target will be asked for its ID value using #finder_id
      # or if that is not set, then the default value defined in the ORM layer.  Particularly for MongoDB
      # it is important that #finder_id be set to an appropriate value sence the Updater ORM layer uses
      # the low level MongoDB driver instead of a more feature complete ORM like Mongoid.
      #
      # == Examples
      #
      #    Updater.at(Chronic.parse('tomorrow'),Foo,:bar,[]) # will run Foo.bar() tomorrow at midnight
      #    
      #    f = Foo.create
      #    u = Updater.at(Chronic.parse('2 hours form now'),f,:bar,[]) # will run Foo.get(f.id).bar in 2 hours
      # == See Also
      # 
      # +in+, +immidiate+ and +chain+ which share the same arguments and options but treat time differently
      def at(t,target,method = nil,args=[],options={})
        hash = Hash.new
        hash[:time] = t.to_i unless t.nil?
        
        hash[:target],hash[:finder],hash[:finder_args] = target_for(target, options)
        
        hash[:method] = method || :perform
        hash[:method_args] = args
        
        [:name,:failure,:success,:ensure].each do |opt|
          hash[opt] = options[opt] if options[opt]
        end
        
        hash[:persistant] = options[:persistant] || t.nil? ? true : false
        
        schedule(hash)
      end
      
      # Run this job in 'time' seconds from now.  See +at+ for details on expected args.
      def in(t,*args)
        at(time.now+t,*args)
      end
      
      # Advanced: This method allows values to be passed directly to the ORM layer's create method.
      # use +at+ and friends for everyday use cases.
      def schedule(hash)
        r = new(@orm.create(hash))
        signal_worker
        r
      rescue NoMethodError
        raise ArgumentError, "ORM not initialized!" if @orm.nil?
        raise
      end

      # Create a new job having the same charistics as the old, except that 'hash' will override the original.
      def reschedule(update, hash={})
        new_job = update.orm.dup
        new_job.update_attributes(hash)
        new_job.save
        new(new_job)
      end

      # like +at+ but with time as time.now.  Generally this will be used to run a long running operation in
      # asyncronously in a differen process.  See +at+ for details
      def immidiate(*args)
        at(time.now,*args)
      end
      
      # like +at+ but without a time to run.  This is used to create requests that run in responce to the 
      # failure of other requests.  See +at+ for details
      def chain(*args)
        at(nil,*args)
      end
      
      # Retrieves all updates for a conforming target possibly limiting the results to the named
      # request.
      #
      # == Parameters
      #
      # target <Class | Object> a class or conforming object that postentially is the calculated target
      # of a request.
      #
      # name(optional) <String>  If a name is sent, the first request with fot this target with this name
      # will be returned.
      #
      # ==Returns
      #
      # <Array[Updater]> unless name is given then only a single [Updater] instance. 
      def for(target,name=nil)
        target,finder,args = target_for(target)
        ret = @orm.for(target,finder,args,name).map {|i| new(i)}
        name ? ret.first : ret
      end
      
            #The time class used by Updater.  See time= 
      def time
        @time ||= Time
      end
      
      # By default Updater will use the system time (Time class) to get the current time.  The application
      # that Updater was developed for used a game clock that could be paused or restarted.  This method
      # allows us to substitute a custom class for Time.  This class must respond with in interger or Time to
      # the #now method.
      def time=(klass)
        @time = klass
      end
      
      # A filter for all requests that are ready to run, that is they requested to be run before or at time.now
      # and ar not being processed by another worker
      def current
        @orm.current
      end
      
      #The number of jobs currently backloged in the system
      def load
        @orm.current_load
      end
      
      #A count of how many jobs are scheduled but not yet run
      def delayed
        @orm.delayed
      end
      
      #How many jobs will happen at least 'start' seconds from now, but not more then finish seconds from now.
      #If the second parameter is nil then it is the number of jobbs between now and the first parameter.
      def future(start,finish = nil)
        start, finish = [0, start] unless finish 
        @orm.future(start,finish)
      end
      
      #Remove all scheduled jobs.  Mostly intended for testing, but may also be useful in cases of crashes
      #or system corruption. removes all pending jobs.
      def clear_all
        @orm.clear_all
      end
      
      # The name of the file to look for information if we loose the server  
      attr_accessor :config_file
      
      #Sets the process id of the worker process if known.  If this 
      #is set then an attempt will be made to signal the worker any
      #time a new update is made.
      #
      #The PID will not be signaled if @socket is availible, but should be set as a back-up
      #
      #If pid is not set, or is set to nil then the scheduleing program 
      #is responcible for waking-up a potentially sleeping worker process
      #in another way.
      def pid=(p)
        return @pid = nil unless p #tricky assignment in return
        @pid = Integer("#{p}") #safety check that prevents a curupted PID file from crashing the system
        Process::kill 0, @pid #check that the process exists
        @pid
      rescue Errno::ESRCH, ArgumentError
        @pid = nil
        raise ArgumentError, "PID was invalid"
      end
      
      # The PID of the worker process
      def pid
        @pid
      end
      
    private
      def signal_worker
        errored = false
        begin
          if @socket
            @socket.write '.'
            logger.debug "Signaled Master Process Via Socket"
          elsif @pid
            Process::kill "USR2", @pid
            logger.debug "Signaled Master Process Via PID"
          else
            signal_worker if connection_refresh
          end
        rescue SystemCallError
          logger.warn "Lost Client Connection to Updater Server"
          if connection_refresh && !errored
            errored = true
            retry
          end
        end
      end
      
      def connection_refresh
        logger.debug "Connection Refresh Attempted"
        @socket.close if @socket
        @socket = nil; @pid = nil #assume the old server died
        @connection_refresh ||= [1,Time.now-1]
        delay, time = @connection_refresh
        if Time.now >= time+delay
          Setup.new(@config_file, :logger=>logger).client_setup
          if @pid || @socket #assume we were successful and retry
            @connection_refresh = nil 
            return true
          else
            logger.debug "Connection Refresh Failed"
            #we are still not able to connect, don't try again for a while
            @connection_refresh= [[delay*2,10*60].min,Time.now]
            return false
          end
        end
        logger.debug "Connection Refresh Waiting until #{time+delay}"
        return false
      end
      
      # Given some instance return the information needed to recreate that target 
      def target_for(inst,options = {})
        return [inst, options[:finder], options[:finder_args]] if (inst.kind_of?(Class) || inst.kind_of?(Module))
        [ inst.class, #target's class
          options[:finder] || @finder_method || orm::FINDER, #method to call on targets class to find/create target
          options[:finder_args] || inst.send(@finder_id || orm::ID) #value to pass to above method 
        ]
      end
      
    end # class << self
  end #class Update
  
end #Module Updater