require 'mongo'
require 'active_support/inflector' #to get classes from strings
require 'active_support/core_ext/object/try'

module Updater
  module ORM
    class Mongo
      
      FINDER= :get
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
      
      %w{time finder finder_args method method_args name persistance lock_name}.each do |field|
        eval(<<-EOF)  #,__LINE__+1,__FILE__)
          def #{field};@hash['#{field}'];end
          def #{field}=(value);@hash['#{field}'] = value;end
        EOF
      end
      
      def _id
        @hash['_id'] || @hash[:_id]
      end
      
      def _id=(val)
        val = BSON::ObjectID.from_string(val.to_s) unless val.kind_of? BSON::ObjectID
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
        self.class.collection.save @hash
      end
      
      def destroy
        @collection.remove({:_id=>id})
      end
      
      def [](arg)  #this allows easy mapping for time when a value coud either be U::ORM::Mongo or an ordered hash
        @hash[arg]
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
        eval(<<-EOF) #,__FILE__,__LINE__+1)
          def #{mode}
            @#{mode} ||= init_chain(:#{mode})
          end
        EOF
      end
      
      def init_chain(mode)
        ret = [@hash[mode.to_s] || []].flatten
        unless ret.empty?
          ret = @collection.find(:_id=>{'$in'=>ret}).map {|i| self.class.new(i)}
        end
        ret.define_singleton_method '<<' do |val|
          val = BSON::ObjectID.fron_string(val) if val.kind_of? String
          aval,hval = case val
            when self.class
              [val,val.id]
            when Hash
              [self.class.new(val),val['_id']]
            when BSON::ObjectID
              [@collection.find_one(val),val]
          end
          @hash[mode] ||= []
          @hash[mode] << hval
          super aval
        end
      end
      
      def lock(worker)
        raise NotImplimentedError, "Use lock_next"
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
          logger ||= options[:logger]
          raise ArgumentError, "Must spesify the name of a databas when setting up Mongo driver" unless options[:database]
          if options[:database].kind_of? ::Mongo::DB
            @db = options[:database]
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
        
        def lock_next(worker)
          hash = Hash.new
          hash['findandmodify'] =@collection.name
          hash['query'] = {:time=>{'$lte'=>tnow},:lock_name=>nil}
          hash['sort'] =[[:time,'ascending']] #oldest first
          hash['update'] = {'$set'=>{:lock_name=>worker.name}}
          hash['new'] = true
          
          ret = @db.command hash
          return nil unless ret['ok'] == 1
          return new(ret['value'])
        end 
        
        def get(id)
          id = BSON::ObjectID.from_string(id) if id.kind_of? String
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
          nxt = @collection.find_one({:time=>{'$gt'=>3,'$lt'=>4}, :lock_name=>'foobar'}, :sort=>[[:time, :asc]], :fields=>[:time])
          return nil unless nxt
          return 0 if nxt['time'] <= tnow
          return nxt['time'] - tnow
        end
        
        def create(hash)
          new(hash).save
        end
        
        def clear_all
          @collection.remove
        end
        
        def clear_locks(worker)
          coll.update({:lock_name=>worker.name},{'$unset'=>{:lock_name=>1}},:multi=>true)
        end
        
        private
        def tnow
          Updater::Update.time.now.to_i
        end
      end
      
    end
  end
end
