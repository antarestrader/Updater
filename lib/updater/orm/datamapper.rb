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
      property :time, Integer, :index=>true
      property :target, Class, :index=>:for_target
      property :finder, String, :index=>:for_target
      property :finder_args, Yaml, :index=>:for_target
      property :method, String
      property :method_args, Object, :lazy=>false
      property :name, String, :length=>255, :index=>true
      property :lock_name, String
      property :persistant, Boolean
      
      has n, :chains, :model=>'Updater::ORM::DMChained', :child_key=>[:caller_id]
      
      def method
        self[:method]
      end
      
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
          chains.all(:occasion=>mode).map {|job| Update.new(job.target).tap {|u| u.params = job.params}}
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
        
        #Returns the Locked Job or nil if no jobs were availible.
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
            return nil
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
          search = all(
              :target=>mytarget,
              :finder=>myfinder,
              :finder_args=>myfinder_args, 
              :lock_name=>nil
            )
          myname ? search.all(:name=>myname ) : search
        end
        
        #For the server only, setup the connection to the database
        def setup(options)
          ::DataMapper.logger = options.delete(:logger)
          auto_migrate = options.delete(:auto_migrate)
          ::DataMapper.setup(:default,options)
          ::DataMapper.auto_migrate! if auto_migrate
        end
        
        # For pooled connections it is necessary to empty the pool of the parents connections so that they
        # do not comtiminate the child pool. Note that while Datamapper is thread safe, it is not safe accross a process fork.
        def before_fork
          return unless (defined? ::DataObjects::Pooling)
          return if ::DataMapper.repository.adapter.to_s =~ /Sqlite3Adapter/
          ::DataMapper.logger.debug "+-+-+-+-+ Cleaning up connection pool (#{::DataObjects::Pooling.pools.length}) +-+-+-+-+"
          ::DataObjects::Pooling.pools.each {|p| p.dispose} 
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

      property :params, Object, :required=>false 
      property :occasion, String,  :required=>true
    end

  end#ORM
end#Updater