require "dm-core"
require "dm-types"

module Updater
  module ORM
    class DataMapper
      
      FINDER = :get
      ID = :id
      
      include ::DataMapper::Resource
      
      storage_names[:default] = "updates"
    
      property :id, Serial
      property :time, Integer
      property :target, Class
      property :finder, String
      property :finder_args, Yaml
      property :method, String
      property :method_args, Object, :lazy=>false
      property :name, String
      property :lock_name, String
      property :persistant, Boolean
      
      belongs_to :failure, :model=>self.inspect, :child_key=>[:failure_id], :nullable=>true
      belongs_to :success, :model=>self.inspect, :child_key=>[:success_id], :nullable=>true
      belongs_to :ensure, :model=>self.inspect, :child_key=>[:ensure_id], :nullable=>true
      
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
          nil
        end
      end
      
      #Useful, but not in API
      def locked?
        not @lock_name.nil?
      end
      
      #Useful, but not in API
      def locked_by
        @lock_name
      end
      
      class << self        
        def current
          all(:time.lte=>tnow, :lock_name=>nil)
        end
        
        def current_load;current.count;end
        
        def delayed
          all(:time.gt=>tnow).count
        end
        
        def future(start, finish)
          all(:time.gt=>start+tnow,:time.lt=>finish+tnow).count
        end
        
        def queue_time
          nxt = self.first(:time.not=>nil,:lock_name=>nil, :order=>[:time.asc])
          return nil unless nxt
          return 0 if nxt.time <= tnow
          return nxt.time - tnow
        end
        
        def lock_next(worker)
          updates = worker_set
          unless updates.empty?
            #concept copied form delayed_job.  If there are a number of 
            #different processes working on the queue, the niave approch
            #would result in every instance trying to lock the same record.
            #by shuffleing our results we greatly reduce the chances that
            #multilpe workers try to lock the same process
            updates = updates.to_a.sort_by{rand()}
            updates.each do |u|
              return u if u.lock(worker)
            end
          end
        rescue DataObjects::ConnectionError
          sleep 0.1
          retry
        end
        
        def clear_locks(worker)
          all(:lock_name=>worker.name).update(:lock_name=>nil)
        end
        
      private
        #This returns a set of update requests.
        #The first parameter is the maximum number to return (get a few other workers may be in compitition)
        #The second optional parameter is a list of options to be past to DataMapper.
        def worker_set(limit = 5, options={})
          #TODO: add priority to this.
          options = {:lock_name=>nil,:limit=>limit, :order=>[:time.asc]}.merge(options)
          current.all(options)
        end
        
        def lock
          
        end
        
        def tnow
          Updater::Update.time.now.to_i
        end
        
      end
    end
  end
end