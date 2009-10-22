module Updater

  #the basic class that drives updater
  class Update
    # Contains the Error class after an error is caught in +run+. Not stored to the database.
    attr_reader :error
    
    include DataMapper::Resource
    
    property :id, Serial
    property :target, Class
    property :ident, Yaml
    property :method, String
    property :finder, String
    property :args, Object
    property :time, Integer
    property :name, String
    property :lock_name, String
    
    #will be called if an error occurs
    belongs_to :failure, :model=>'Update', :child_key=>[:failure_id], :nullable=>true
    
    # Returns the Class or instance that will recieve the method call.  See +Updater.at+ for 
    # information about how a target is derived.
    def target
      return @target if @ident.nil?
      @target.send(@finder||:get, @ident)
    end
    
    # Send the method with args to the target.
    def run(job=nil)
      t = target #do not trap errors here
      final_args = job ? sub_args(job,args.dup) : args
      begin
        t.send(@method.to_sym,*final_args)
      rescue => e
        @error = e
        failure.run(self) if failure
        destroy unless nil == time
        return false
      end
      destroy unless nil == time
      true
    end
    
    def sub_args(job,a)
      a.map {|e| :__job__ == e ? job : e}
    end
    
    #atempt to lock this record for the worker
    def lock(worker)
      return true if locked? && locked_by == worker.name
      #all this to make sure the check and the lock are simultanious:
      cnt = repository.update({properties[:lock_name]=>worker.name},self.class.all(:id=>self.id,:lock_name=>nil))
      if 0 != cnt
        @lock_name = worker.name
        true
      else
        worker.say( "Worker #{worker.name} Failed to aquire lock on job #{id}" )
        false
      end
    end
    
    def locked?
      not @lock_name.nil?
    end
    
    def locked_by
      @lock_name
    end
    
    #Like run but first aquires a lock for the worker.  Will return the result of run or nil
    #if the record could not be locked
    def run_with_lock(worker)
      run if lock(worker)
    end
    
    class << self
      
      # Request that the target be sent the method with args at the given time.
      #
      # == Parameters
      # time <Integer | Object responding to to_i>,  by default the number of seconds sence the epoch.  
      #What 'time'  references  can be set by sending the a substitute class to the time= method.
      #
      # target  <Class | instance> .  If target is a class then 'method' will be sent to that class (unless the 
      # finder option is used.  Otherwise, the target will be assumed to be the result of 
      # (target.class).get(target.id).  The finder method (:get by default) and the finder_args 
      # (target.id by default) can be set in the options.  A DataMapper instance passed as the target
      # will "just work."  Any object can be found in this mannor is known as a 'conforming instance'.
      # 
      # method <Symbol>.  The method that will be sent to the calculated target.
      #
      # args <Array> a list of arguments to be sent to with the method call.  Note: 'args' must be seirialiable
      # with Marshal.dump.  Defaults to []
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
      # :failure <Updater> an other request to be run if this request raises an error.  Usually the 
      # failure request will be created with the +chane+ method.
      #
      # == Examples
      #
      #    Updater.at(Chronic.parse('tomorrow'),Foo,:bar,[]) # will run Foo.bar() tomorrow at midnight
      #    
      #    f = Foo.create
      #    u = Updater.at(Chronic.parse('2 hours form now'),f,:bar,[]) # will run Foo.get(f.id).bar in 2 hours
      def at(time,target,method,args=[],options={})
        finder, finder_args = [:finder,:finder_args].map {|key| options.delete(key)}
        hash = {:method=>method.to_s,:args=>args}
        hash[:target] = target_for(target)
        hash[:ident] = ident_for(target,finder,finder_args)
        hash[:finder] = finder || :get
        hash[:time] = time
        create(hash.merge(options))
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
        ident = ident_for(target)
        target = target_for(target)
        if name
          first(:target=>target,:ident=>ident,:name=>name)
        else
          all(:target=>target,:ident=>ident)
        end
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
      
      #A filter for all requests that are ready to run, that is they requested to be run before or at time.now
      def current
        all(:time.lte=>time.now.to_i)
      end
      
      #A filter for all requests that are not yet ready to run, that is time is after time.now
      def delayed
        all(:time.gt=>time.now.to_i)
      end
      
      #This returns a set of update requests.
      #The first parameter is the maximum number to return (get a few other workers may be in compitition)
      #The second optional parameter is a list of options to be past to DataMapper.
      def worker_set(limit = 5, options={})
        #TODO: add priority to this.
        options = {:limit=>limit, :order=>[:time.desc]}.merge(options)
        current.all(options)
      end
      
      ####################
      # Worker Functions #
      ####################
      
      #Gets a single gob form the queue, locks and runs it.
      def work_off(worker)
        updates = worker_set
        if updates.empty?
          return queue_time
        end
        
        #concept copied form delayed_job.  If there are a number of 
        #different processes working on the queue, the niave approch
        #would result in every instance trying to lock the same record.
        #by shuffleing our results we greatly reduce the chances that
        #multilpe workers try to lock the same process
        updates = updates.to_a.sort_by{rand()}
        updates.each do |u|
          t = u.run_with_lock(worker)
          return queue_time unless nil == t
        end
      end
      
      def queue_time
        nxt = self.first(:time.not=>nil, :order=>[:time.desc])
        return nil unless nxt
        return 0 if nxt.time <= time.now.to_i
        return nxt.time - time.now.to_i
      end
      
      
      
    private
      
      # Computes the stored class an instance or class
      def target_for(inst)
        return inst if inst.kind_of? Class
        inst.class
      end
      
      # Compute the agrument sent to the finder method
      def ident_for(target,finder=nil,args=nil)
        if !(target.kind_of?(Class)) || finder
          args || target.id
        end
        #Otherwize the target is the class and ident should be nil
      end
    
    end
    
    #:nodoc:
    def inspect
      "#<Updater id=#{id} target=#{target.inspect} time=#{time}>"
    end
  end
  
end