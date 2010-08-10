module Updater
  module ORM
    
    # This is the root class for ORM inplimentations.  It provides some very
    # basicfunctionality that may be useful for implimenting actuall ORM's
    # but cannot itself be run or instantiated.  The documentation for this
    # class also serves as the cannonical reference for the ORM API.
    #
    # for purposes of this documentation instances of a class inheriting form 
    # this class will be refered to as 'jobs.' 
    # 
    # In addation to the methods listed below, it MUST provide accessors for the 
    # 12 fields below.  Most ORMs will add these when the fields are setup
    #
    # == Fields
    # 
    # These fields with thier getters and setters (except id which is read only) are expected
    # to be implimented in every ORM implimention.  Other fields may be implimented as
    # well, but clients SHOULD NOT depend on or manipulate them.  ORM will need to 
    # impliment some persistant way to lock records, and should do so in such a way as the
    # name of the worker can be tracked, and jobs cleared for that worker should it crach
    # if the underlying datastore allows.
    #
    # id: a unique value asigned to each job. For purposes of the API it is a black box
    # which should be paseed to the ClassMethods#get method to retrieve the job.  If
    # the ORM uses a different name for this value such as _id or key, a reader method
    # must be implimented as id.
    #
    # time [Integer]:  This is the time in seconds at which the job should be run.  It is
    # always in reference to Updater::Update.time (by default Time).  This value will be
    # nil for chained methods.
    #
    # target [Class]: The class of the target for this job.  the API spesifies that it must be
    # a Ruby class currently in scope in both the workers' and clients' frames of reference.
    # (see configuration documentation for how to achieve this.)  The writer must accept an
    # actual class, which it may store in the datastore as a string (by calling to_s on it).  The
    # reader method must return the actual class by if ecessary calling Object.const_get(str)
    # with the stored value.
    #
    # finder [String]: A method to call on the Target in orderto get the target instance.
    # The API limits its length to no more then 50 charactors.  If the class itself is the
    # target, this value will either not be set or set to nil.  The reader should MUST return
    # nil in this case.
    #
    # finder_args [Array]: A possibly complex array of valuse that will be paseed to the
    # finder method in order to retrieve the target instance.  The API spesifies that the
    # array and all subelements must impliment the #to_yaml and #to_json method in
    # addation to being Marshalable. If the class itself is the
    # target, this value will either not be set or set to nil.  The reader should MUST return
    # nil in this case.
    #
    # method [String]:  The method to be sent to the target instance.  The API limits this value
    # to 50 charictars.  It MAY NOT be nil or empty.
    #
    # method_args [Array]: A possibly complex array of values to pass to the spesified method of
    # the target instance.  It must be marshalable.  The ORM layer is responcible to Marshal.dump
    # and Marshal.load these values.
    #
    # name [String]: If the ORM impliments the +for+ method, then it MUST store a name which the
    # API spesifies SHOULD be unique per target.  The ORM SHOULD NOT enforce this restriction, but
    # MAY assume it.   ORM's that do not impliment +for+ must none the less have a #name= method
    # that returns the value passed to it (as is normal with setter methods) and must not raise an error
    # when a hash of values includes name.  It must also respond to the name method with nil.  When
    # inplimented, name may be no longer then 255 characters.
    #
    # persistant [Boolean]: if this value is set to true a worker will not call destroy after running the job.
    # If it is nil or not set it may be assumed to be false,  and ORM may return nil instead of false in this
    # case.
    #
    # == Chained Jobs
    #
    # Chained Jobs are run after a job and allow for various function to take place such as logging and
    # error handleing.  There are three(3) categories for chaining :failure, :success, and :ensure.  The
    # ORM must impliment a getter and setter for each as described below.  This version does not
    # inpliment it, but ORMs should be be designed in such a way that :prior and :instead chains can be
    # added in future version of this API.
    # 
    # === Getters: 
    # getters should return an array of structures (Struct or equivelent)  representing the chained jobs
    # for this job.  The structure should have three(3) members and MAY be read-only.
    #
    # caller: An instance of the ORM class for the job in question (i.e. self)
    #
    # target: An instance of the ORM class for the chained job
    #
    # params: a Hash or other object that will be substituted for the special value '__params__' when calling
    # the target job.
    #
    # The object returned may have other methods and functionality.  Clients SHOULD NOT antisipate or use
    # these methods.
    # 
    # === Setters:
    # setters must accept five(5) differnt types of input.  Except as described below setters are NOT distructive,
    # that is job.failure=logme adds logme to the list of failure jobs and does not remove jobs that may have previously
    # been chained.  Clients should call save after using the setter to write the changes to disk
    #
    # ORM or Updater::Update:  Add this job to the chain, with no parameters. Updater::Update#orm will give the job.
    #
    # Array<ORM or Updater::Update>: Add each job in the array to the chain
    #
    # Hash(<ORM or Updater::Update>, params): Add the keys to the chain with the valuse as params.  Clients
    # should note that it is not possible to add multiple calls to the same job using this method.
    #
    # nil:  remove all jobs from this chain.  Clients Note, that this is the only way to remove a previously added
    # job from a chain.
    class Base
      
      # Every ORM should set this constant to a symbol that matches the most
      # obvious method used to retrive a known instance.  :get or :find are likely
      # candidates. 
      FINDER= nil
      
      # every ORM should set this to a method when called on an object producted by
      # that ORM will give a value that can be passed to the FINDER method to retrieve
      # the object from the datastore.  :id, _id, or :key are likely candidates
      ID = nil
      
      # Workers will call this method on a job before running it to insure that in the case
      # of multiple workers hiting the same queue only one will run the job.  The worker 
      # MUST pass itself to Lock, and the implimentation MAY use the name of the worker
      # to identify who has locked this job.  
      #
      # If a worker is successfully able to lock this job, or has already locked the Job, this 
      # method MUST return a true value.  If a lock was unsuccessful, it MUST return the
      # value false, and MAY use the 'say' method of the suplied worker to explain why a lock
      # could not be aquired.
      def lock(worker)
        NotImplementedError
      end
      
      #write any changes made to the job back to the datastore.
      def save
        NotImplementedError
      end
      
      #Remove this job from the datastore.
      def destroy
        NotImplementedError
      end
      
    end
    
    class ClassMethods
      
      # When passed the value returned by the #id method of a job, this method must return
      # that job from the datastore.
      def get(id)
        NotImplementedError
      end
      
      # The hash keys are symbols for the one of the 12 field values listed in the intro to the 
      # ORM::Base class.  The values are the actual values that should be returned by the 
      # accessor methods.  Depending on the datastore some values may need to be marshaled
      # converted, etc.. before being written to the datastore.
      def create(hash)
        NotImplementedError
      end
      
      # This method returns all jobs that are now ready to run, that is thier time valuse is less
      # then or equal to the value returned by calling now on the registered time class (tnow).
      def current
        NotImplementedError
      end
      
      # Returns a count of how many jobs are currently ready to run.
      def current_load
        NotImplementedError
      end
      
      # Runurns a count of the number of jobs scheduled to run at a later time, that is there
      # time value is strictly greater then the value returned by calling now on the registered 
      # time class(tnow)
      def delayed
        NotImplementedError
      end
      
      # Returns a count of how may jobs are curently scheduled between start and finish seconds 
      # from now.  e.g future(0,60) would tell you how many jobs will run in the next minute.  This
      # function is used to adjust the number of workers needed as well as for monitering.
      def future(start, finish)
        NotImplementedError
      end
      
      # Returns the number os seconds until the next job will be ready to run.  If there are no
      # Jobs in the queue it returns nil,  if there is at least one job ready to run it MUST return
      # 0.  This may be an apporximation or the value may be cached for brief periods to improve
      # datastore performance.
      def queue_time
        NotImplementedError
      end
      
      # Locks to a worker and returns a job that is ready to run.  Workers will call this when they are
      # ready for another job.  In general it should lock jobs in the order they were recieved or scheduled,
      # but strict ordering is not a requirement. (c.f. delayed_job).  If there are current jobs, this method
      # MUST return one which has been locked successfully, internally trying successive current jobs if 
      # the first one fails to lock.  It MUST NOT raise an error or return nil if the datastore is temerarly 
      # busy.  Instead it must wait until it can either get access to and lock a record, or prove that no jobs
      # are current.
      #
      # In the event that there are no current jobs left in the datastore this method should retunr nil.  The
      # should inturperate this as a sign that the queue is empty and consult +queue_time+ to determine
      # how long to wait for the next job.
      def lock_next(worker)
        NotImplementedError
      end
      
      # This method unlocks and makes availible any and all jobs which have been locked by the worker.
      # Workers are uniquely identified by the +name+ method.  This is an indication that the worker has
      # died or been killed and cannot complete its job.
      def clear_locks(worker)
        NotImplementedError
      end
      
      # Compleatly remove all jobs and associeted data from the datastore including chained
      # Methods.
      def clear_all
        NotImplementedError
      end
      
      # This method is the generic way to setup the datastore.  Options is a hash one of whose fields
      # will be :logger, the logger instance to pass on to the ORM.  The rest of the options are ORM 
      # spesific.  The function should prepair a connection to the datastore using the given options.
      # If the connection cannot be prepaired then an appropriate error should be raised.
      def setup(options)
        NotImplementedError 
      end
      
      # This method is called by the child before a fork call.  It allows the ORM to clean up any connections
      # Made by the parent and establish new connections if necessary.
      def before_fork
        
      end
      
      def after_fork
      
      # Optional, but strongly recomended.
      #
      # For any datastore that permits, return and Array of all delayed, chained, and current but not locked jobs that reference 
      # mytarget, myfinder, and myfinder_args,  that is they clearly have the spesified Target.  Optionally, limit the result to 
      # return the first job that also has a name value of myname.  The name value is spesified as unique per target so the 
      # which record is returned in the case that multiple jobs fro the same target share the same name is undefined.
      def for(mytarget, myfinder, myfinder_args, myname=nil)
        NotImplementedError
      end
      
      private
      
      #Short hand method that retruns the current time value that this queue is using.
      def tnow
        Updater::Update.time.now.to_i
      end
      
    end
  end
end