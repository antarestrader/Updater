module Updater
  module Target
    def self.included(model)
      model.class_eval do
        class << self
          attr_accessor :updater_finder_method
          attr_accessor :updater_id_method
        end
      end
      
      super
    end
  
    def jobs_for(name = nil)
      Update.for(self, name)
    end
    
    alias job_for jobs_for
    
    def enqueue(*args)
      Update.immidiate(self,*args)
    end
    
    alias send_later enqueue
    
    def send_at(time, *args)
      Update.at(time,self,*args)
    end
    
    def send_in(delta_seconds,*args)
      Update.in(delta_seconds,self,*args)
    end
  end
end