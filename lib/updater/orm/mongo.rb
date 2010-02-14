require 'mongo_mapper'

module Updater
  module ORM
    class Mongo
      
      
      
      FINDER= :find
      ID=:_id
      
      include ::MongoMapper::Document
      
      key :time, Integer, :numeric=>true
      key :target, String, :required => true
      key :finder, String
      key :finder_args, Array
      key :method, String :required => true
      key :method_args, String :required => true
      key :name
      key :persistant
      key :lock_name
      
      %w{failure success ensure}.each do |mode|
        
      end
      
      def lock(worker)
        raise NotImplimentedError, "Use lock_next"
      end
      
      class << self
        def lock_next(worker)
          hash = OrderedHash.new
          hash['findandmodify'] =collection.name
          hash['query'] = {:time=>{'$lte'=>tnow},:lock_name=>nil}
          hash['sort'] = {:time=>1} #oldest first
          hash['update'] = {'$set'=>{:lock_name=>worker.name}}
          hash['new'] = true
          
          ret = database.command hash
          return nil unless ret['ok'] == 1
          return load(ret['value'])
        end 
        
        def get(id)
          find(id)
        end
        
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
        
        private
        def tnow
          Updater::Update.time.now.to_i
        end
      end
      
    end
  end
end