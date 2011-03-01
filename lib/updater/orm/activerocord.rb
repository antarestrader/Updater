module Updater
  module ORm

    class ActiveRecord
      raise NoImplimentationError
      def lock(worker)
        return true if locked? && locked_by == worker.name
        #all this to make sure the check and the lock are simultanious:
        ccnt = self.class.where(id: self.id, lock: nil).update_all(:lock=>worker.name)
        if 0 != cnt
          @lock_name = worker.name
          true
        else
          worker.say( "Worker #{worker.name} Failed to aquire lock on job #{id}" )
          false
        end
      end
      
    end
    
  end
  
end