module Updater
  class TargetMissingError < StandardError
  end

  #the basic class that drives updater
  class Update
    # Contains the Error class after an error is caught in +run+. Not stored to the database
    attr_reader :error
    attr_reader :orm
    
    #Run the action on this traget compleating any chained actions
    def run(job=nil,params=nil)
      ret = true #put return in scope
      begin
        t = target 
        final_args = sub_args(job,params,@orm.method_args)
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
        rescue DataObjects::ConnectionError
          sleep 0.1
          retry
        end
      end
      ret
    end
    
    def method_missing(method, *args)
      @orm.send(method,*args)
    end
    
    def target
      target = @orm.finder.nil? ? @orm.target : @orm.target.send(@orm.finder,@orm.finder_args)
      raise TargetMissingError, "Target missing --Class:'#{@orm.target}' Finder:'#{@orm.finder}', Args:'#{@orm.finder_args.inspect}'" unless target
      target
    end
    
    def initialize(orm_inst)
      @orm = orm_inst
    end
    
    def name=(n)
      @orm.name=n
    end
    
    def name
      @orm.name
    end
    
    #This is the appropriate valut ot use for a chanable field value
    def id
      @orm.id
    end
    
    def persistant?
      @orm.persistant
    end
    
    def inspect
      "#<Updater::Update target=#{target.inspect} time=#{orm.time}>"
    rescue TargetMissingError
      "#<Updater::Update target=<missing> time=#{orm.time}>"
    end
    
  private
      
    def sub_args(job,params,a)
      a.map do |e| 
        begin
          case e.to_s
            when '__job__'
              job
            when '__params__'
              params
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
    
    def run_chain(name)
      chains = @orm.send(name)
      return unless chains
      chains.each do |job|
        Update.new(job.target).run(self,job.params)
      end
    rescue NameError
      puts @orm.inspect
      raise
    end
    
    class << self
      
      #This attribute must be set to some ORM that will persist the data
      attr_accessor :orm
      
      # This is an open IO socket that will be writen to when a job is scheduled. If it is unset
      # then @pid is signaled instead.
      attr_accessor :socket
      
      #Gets a single job form the queue, locks and runs it.  it returns the number of second
      #Until the next job is scheduled, or 0 is there are more current jobs, or nil if there 
      #are no jobs scheduled.
      def work_off(worker)
        inst = @orm.lock_next(worker)
        new(inst).run if inst
        @orm.queue_time
      ensure
        clear_locks(worker)
      end
      
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
      # valuses will be created with the +chained+ method.  As an alternative a hash with keys of Updater::Update instances and
      # values of Hash may be used.  The hash will be substituted for the '__param__' argument if/when the chained method is called.
      # 
      # :persistant <true|false> if true the object will not be destroyed after the completion of its run.  By default
      # this is false except when time is nil.
      #
      # == Examples
      #
      #    Updater.at(Chronic.parse('tomorrow'),Foo,:bar,[]) # will run Foo.bar() tomorrow at midnight
      #    
      #    f = Foo.create
      #    u = Updater.at(Chronic.parse('2 hours form now'),f,:bar,[]) # will run Foo.get(f.id).bar in 2 hours
      def at(t,target,method = nil,args=[],options={})
        hash = Hash.new
        hash[:time] = t.to_i unless t.nil?
        
        hash[:target],hash[:finder],hash[:finder_args] = target_for(target)
        hash[:finder] = options[:finder] || hash[:finder]
        hash[:finder_args] = options[:finder_args] || hash[:finder_args]
        
        hash[:method] = method || :process
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
        #TODO
      end
      
            #The time class used by Updater.  See time= 
      def time
        @@time ||= Time
      end
      
      # By default Updater will use the system time (Time class) to get the current time.  The application
      # that Updater was developed for used a game clock that could be paused or restarted.  This method
      # allows us to substitute a custom class for Time.  This class must respond with in interger or Time to
      # the #now method.
      def time=(klass)
        @@time = klass
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
      #or system corruption
      def clear_all
        @orm.clear_all
      end
      
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
        @pid = Integer("#{p}")
        Process::kill 0, @pid
        @pid
      rescue Errno::ESRCH, ArgumentError
        @pid = nil
        raise ArgumentError, "PID was invalid"
      end
      
      def pid
        @pid
      end
      
    private
      def signal_worker
        if @socket
          @socket.write '.'
        elsif @pid
          Process::kill "USR2", @pid
        end
      end
      
      # Given some instance return the information needed to recreate that target 
      def target_for(inst)
        return [inst, nil, nil] if inst.kind_of? Class
        [inst.class,@orm::FINDER,inst.send(orm::ID)]
      end
      
    end
  end #class Update
  
end #Module Updater