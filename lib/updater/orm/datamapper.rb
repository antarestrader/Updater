require "dm-core"
require "dm-types"

module Updater
  module ORM
    class DMChained
      include ::DataMapper::Resource
      storage_names[:default] = "update_chains"
      property :id, Serial
    end

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
      property :name, String, :length=>255
      property :lock_name, String
      property :persistant, Boolean
      
      has n, :chains, :model=>'Updater::ORM::DMChained', :child_key=>[:caller_id]
      
      #attempt to lock this record for the worker
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
      
      #def failure
      #def failure=
      #def success
      #def success=
      #def ensure
      #def ensure=
      %w{failure success ensure}.each do |mode|
        define_method "#{mode}=" do |chain|
          case chain
            when self.class
              chains.new(:target=>chain,:occasion=>mode)
            when Updater::Update
              chains.new(:target=>chain.orm,:occasion=>mode)
            when Hash
              chain.each do |target, params|
                target = target.orm if target.kind_of? Updater::Update
                chains.new(:target=>target,:params=>params, :occasion=>mode)
              end
            when Array
              chain.each do |target|
                target = target.orm if target.kind_of? Updater::Update
                chains.new(:target=>target,:occasion=>mode)
              end
            when nil
              chains=[]
            else
              raise ArgumentError
          end
        end

        define_method mode do
          chains.all(:occasion=>mode)
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
        
        def clear_all
          all.destroy!
          DMChained.all.destroy!
        end
        
        def for(mytarget, myfinder, myfinder_args, myname=nil)
          search = all(:target=>mytarget,:finder=>myfinder,:finder_args=>myfinder_args, :name=>myname)
        end
        
        def setup(options)
          ::DataMapper.logger = options.delete(:logger)
          ::Datamapper.setup(:default,options)
        end
        
        # For pooled connections it is necessary to empty the pool of the parents connections so that they
        # do not comtiminate the child pool. Note that while Datamapper is thread safe, it is not safe accross a process fork.
        def before_fork
          DataObjects::Pooling.pools.each {|p| p.dispose} if defined? DataObjects::Polling
        end
        
        def after_fork
          
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
    
    class DMChained
      belongs_to :caller, :model=>Updater::ORM::DataMapper, :child_key=>[:caller_id]
      belongs_to :target, :model=>Updater::ORM::DataMapper, :child_key=>[:target_id]

      property :params, Object, :nullable=>true #:required=>false
      property :occasion, String,  :nullable=>false #:required=>true
    end

  end#ORM
end#Updater