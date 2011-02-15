require 'mongo'
require 'active_support/inflector' #to get classes from strings
require 'active_support/core_ext/object/try'

module Updater
  module ORM
    class Mongo
            
      FINDER= :find_one
      ID=:_id
      
      def initialize(hash = {})
        @hash = {}
        hash.each do |key, val|
          if respond_to? "#{key}="
            send("#{key}=", val)
          else
            @hash[key] = val
          end
        end
      end
      
      %w{time finder finder_args method method_args name persistant lock_name}.each do |field|
        eval(<<-EOF)  #,__LINE__+1,__FILE__)
          def #{field};@hash['#{field}'];end
          def #{field}=(value);@hash['#{field}'] = value;end
        EOF
      end
      
      def _id
        @hash['_id'] || @hash[:_id]
      end
      
      def _id=(val)
        val = BSON::ObjectId.from_string(val.to_s) unless val.kind_of? BSON::ObjectId
        @hash[:_id] = val
      end
      
      alias :id :_id
      alias :'id=' :'_id='
      
      def target
        @hash['target'].try :constantize
      end
      
      def target=(value)
        @hash['target'] = value.to_s
      end
      
      def save
        #todo validation
        [:failure,:success,:ensure].each do |mode|
          next unless @hash[mode]
          @hash[mode] = @hash[mode].map do |job|
            if job.kind_of? Updater::Update
              job.save unless job.id
              job = job.id
            end
            job
          end
        end
        _id = self.class.collection.save(@hash, :safe=>true)
      end
      
      def destroy
        self.class.collection.remove({:_id=>id})
      end
      
      def [](arg)  #this allows easy mapping for time when a value coud either be U::ORM::Mongo or an ordered hash
        @hash[arg]
      end
      
      def lock(worker)
        raise NotImplimentedError, "Use lock_next"
      end
      
      # Non API Standard.  This method returns the collection used by this instance.
      # This is used to create Job Chains
      def collection
        self.class.instance_variable_get(:@collection)
      end

      #key :time, Integer, :numeric=>true
      #key :target, String, :required => true
      #key :finder, String
     # key :finder_args, Array
      #key :method, String :required => true
      #key :method_args, String :required => true
      #key :name
     # key :persistant
      #key :lock_name
      
      %w{failure success ensure}.each do |mode|
        eval(<<-EOF, binding ,__FILE__, __LINE__+1)
          def #{mode}
            @#{mode} ||= init_chain(:#{mode})
          end
          
          def #{mode}=(chain)
            chain = [chain] unless chain.kind_of? Array
            @#{mode} , @hash[:#{mode}]  = build_chain_arrays(chain)
            attach_intellegent_insertion(@#{mode},:#{mode},self) if @#{mode}
          end
        EOF
      end
      
    private
      # this method is calld from he chain asignment methods eg. failure=(chain) 
      # chain is an array which may contain BSON::ObjectId's or Updater::Update's or both
      # For BSON::ObjectId's we cannot initialize them as this could leed to infinate loops.
      # (an object pool would solve this problem, but feels like overkill)
      # The final result must be a @hash containing all the BSON::ObjectId' (forign keys)
      # and possibly @failure containting all instanciated UpdaterUpdates read to be called
      # or @failure set to nil with the chain instanciated on first use.
      def build_chain_arrays(arr, build = false)
        build ||= arr.any? {|j| k,_ = j; Updater::Update === k || Hash === k}
        output = arr.inject({:ids=>[],:instances=>[]}) do |accl,j|
          inst, id = rationalize_instance(j)
          if inst.nil? && build
            real_id,params = id #id could be an array
            inst = Updater::Update.new(self.class.new(collection.find_one(real_id)))
            inst.params = params #set params to the second element of the id array.  If id is scale then  set to nil.
          end
          accl[:ids] << id || inst #id will be nil only if inst has not ben saved.
          accl[:instances] << inst if inst
          accl
        end
        if build
          return [output[:instances],output[:ids]]
        end
        [nil,output[:ids]]
      end
      
      # This method takes something that may be a reference to an instance(BSON::ObjectId/String),
      # an instance its self (Updater::Update), or a Hash 
      # and returns a touple of the  Updater::Update,BSON::ObjectId.
      # This method will bot instanciate object from BSON::ObjectId's
      # nor will it save Hashes inorder to obtain an ID (it will creat a new Updater::Update from the hash).
      # Instead it will return nil in the appropriate place.
      def rationalize_instance(val)
        val = BSON::ObjectId.fron_string(val) if val.kind_of? String
        case val  #aval is the actual runable object, hval is a BSON::ObjectId that we can put into the Database
          when Updater::Update
            val.params ? [val,[val.id,val.params]] : [val,val.id]
          when Hash
            [Updater::Update.new(val),val['_id']]
          when BSON::ObjectId
            [nil,val]
          when Array
            rationalize_instance(val[0]).tap do |ret| 
              ret[0].params = val[1] if ret[0]
              ret[1] = [ret[1],val[1]]
            end
        end  
      end
      
      def attach_intellegent_insertion(arr,mode,parent)
        arr.define_singleton_method '<<' do |val|
          inst, id = rationalize_instance(val)
          inst = Updater::Update.new(self.class.new(parent.collection.find_one(id))) unless inst
          parent.instance_variable_get(:@hash)[mode] ||= []
          parent.instance_variable_get(:@hash)[mode] << id || inst
          super inst
        end
        arr
      end
      
      def init_chain(mode)
        ret, @hash[mode] = build_chain_arrays(@hash[mode] || [],true)
        attach_intellegent_insertion(ret,mode,self)
      end
      
      class << self
        attr_accessor :db, :collection, :logger
        
        # Availible options:
        # * :database - *required* either an established Mongo::DB database OR the name of the database 
        # * :collection - which collection to store jobs in. Default: "updater"
        #
        # If a connection to the database must be established (ie :database is not a Mongo::DB)
        # these options may be used to establish that connection.
        # * :host - the host to connect to.  Default: "localhost"
        # * :port - the port to connect to.  Default: 27017
        # * :username/:password - if these are present, they will be used to authenticate against the database
        def setup(options)
          logger ||= options[:logger] || Update.logger
          raise ArgumentError, "Must spesify the name of a database when setting up Mongo driver" unless options[:database]
          if options[:database].kind_of? ::Mongo::DB
            @db = options[:database]
            options[:database] = @db.name
            logger.info "Updater is using already established connection to #{@db.name}"
          else
            logger.info "Attempting to connect to mongodb at #{[options[:host] || "localhost", options[:port] || 27017].join(':')} database: \"#{options[:database]}\""
            @db = ::Mongo::Connection.new(options[:host] || "localhost", options[:port] || 27017).db(options[:database].to_s)
            if options[:username] && options[:password]
              success = db.authenticate(options[:username] , options[:password])
              raise RunTimeError, "Could not Authenticate with MongoDb \"#{options[:database]}\" Please check the username and password."
            end
          end
          collection_name = options[:collection] || 'updater'
          unless db.collection_names.include? collection_name
            logger.warn "Updater MongoDB Driver is creating a new collection, \"#{collection_name}\" in \"#{options[:database]}\""
          end
          @collection = db.collection(collection_name)
        end
        
        def before_fork
          @db.connection.close
        end
        
        def after_fork
          
        end
        
        def lock_next(worker)
          hash = Hash.new
          hash['findandmodify'] =@collection.name
          hash['query'] = {:time=>{'$lte'=>tnow},:lock_name=>nil}
          hash['sort'] =[[:time,'ascending']] #oldest first
          hash['update'] = {'$set'=>{:lock_name=>worker.name}}
          hash['new'] = true
          
          
          ret = @db.command hash, :check_response=>false
          return nil unless ret['ok'] == 1
          return new(ret['value'])
        end 
        
        def get(id)
          id = BSON::ObjectId.from_string(id) if id.kind_of? String
          new(@collection.find_one(id))
        end
        
        def current
          raise NotImplementedError, "Mongo does not support lazy evaluation"
        end
        
        def current_load
          @collection.find(:time=>{'$lte'=>tnow}, :lock_name=>nil).count
        end
        
        def delayed
          @collection.find(:time=>{'$gt'=>tnow}).count
        end
        
        def future(start, finish)
          @collection.find(:time=>{'$gt'=>start+tnow,'$lt'=>finish+tnow}).count
        end
        
        def queue_time
          nxt = @collection.find_one({:lock_name=>nil, :time=>{'$ne'=>nil}}, :sort=>[[:time, :asc]], :fields=>[:time])
          # logger.debug {"  the queue is empty"} unless nxt
          return nil unless nxt
          return 0 if nxt['time'] <= tnow
          return nxt['time'] - tnow
        end
        
        def create(hash)
          ret = new(hash)
          ret.save and ret
        end
        
        def clear_all
          @collection.remove
        end
        
        def clear_locks(worker)
          @collection.update({:lock_name=>worker.name},{'$unset'=>{:lock_name=>1}},:multi=>true)
        end
        
        def for(target,finder,args,name)
          if name
            @collection.find(:target=>target.to_s, :finder_args=>args,:name=>name)
          else
            @collection.find(:target=>target.to_s, :finder_args=>args)
          end
        end
        
        private
        def tnow
          Updater::Update.time.now.to_i
        end
      end
      
    end
  end
end
