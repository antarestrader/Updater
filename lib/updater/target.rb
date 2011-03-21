module Updater

  # By including this module in a client's classes, it is possible to schedule jobs with the 
  #  inlcuded methods.  This saves typing `Updater::Update.[in|at|immidate] `repeatedly.
  #  The class also allows you to set special finder and ID methods on a per class basis.
  module Target
    def self.included(model)
      model.class_eval do
        class << self
          
          # This will overide the default finder for Update and the chosen ORM. Set
          # it the symbol of a class method that can find/instantiate instances of the class.
          # It will be passed the value returned from the ID method called on an 
          # instance.  The ID method can be overridden as well.  See +updater_id_method+
          attr_accessor :updater_finder_method
          
          # This will overide the ID method set in both with Update and the chosen ORM.
          # Set it to the symbol of an instance method.  The value of this method will be given
          # to the finder method in order to recreate the instance for the worker.  The finder
          # method can be overridden as well.  See +updater_finder_method+
          attr_accessor :updater_id_method
        end
      end
      
      super
    end

    # Finds all the jobs whose target is this instance.  If a name is given, it will
    # return only the job with that name set.  There can be only one job with a
    # given name per unique target.  Also note that jobs that have their finder
    # or finder_args set on creation cannot be named and will not be found by
    # this method.  See aslo Update#for
    def jobs_for(name = nil)
      Update.for(self, name)
    end
    
    alias job_for jobs_for
    
    # Place a job on the queue for immidiate execution. This method is aliased
    # to `send_later` for compatibility with delayed_job. See Also Update#immidiate
    def enqueue(*args)
      Update.immidiate(self,*args)
    end
    
    alias send_later enqueue
    
    #Put a job on the queue to run at a spesified time. See Also Update#at
    def send_at(time, *args)
      Update.at(time,self,*args)
    end
    
    #Put a job on the queue to run after a spesified duration (in seconds). See Also Update#in
    def send_in(delta_seconds,*args)
      Update.in(delta_seconds,self,*args)
    end
  end
end