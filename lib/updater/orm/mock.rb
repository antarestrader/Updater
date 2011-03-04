module Updater
  module ORM
    class Mock
      
      FINDER = :find
      
      ID = :id
      
      class << self
        attr_accessor :logger
        
        def index
          @index ||= 0
          @index += 1
        end
        
        def get(id)
          storage[id]
        end
        
       def create(hash)
          new(hash).tap {|n| storage[n.id] = n}
        end
        
        def current
          storage.values.find_all{|x|
            x.time && x.time <= tnow && !x.lock_name 
          }.sort{|a,b| a.time <=> b.time}
        end
        
        def current_load
          current.length
        end
        
        def _delayed
          storage.values.find_all{|x|
            x.time && x.time > tnow
          }.sort{|a,b| a.time <=> b.time}
        end
        
        def delayed
          _delayed.length
        end
        
        def future(start, finish)
          _delayed.find_all{|x| x.time >= start+tnow && x.time < finish+tnow}
        end
        
        def queue_time
          return 0 unless current.empty?
          return nil if (d = _delayed).empty? #tricky assignment in conditional
          d.first.time - tnow
        end
        
        def lock_next(worker)
          job = current.first
          job.lock(worker) if job
          job
        end
        
        def clear_locks(worker)
          storage.values.each{|x| x.lock_name = nil if x.lock_name == worker.name}
        end
        

        def clear_all
          @storage = {}
        end

        def setup(options)
          @storage = {} 
        end
        
        def for(mytarget, myfinder, myfinder_args, myname=nil)
          NotImplementedError
        end
        
        def storage
          @storage ||= {}
        end
        
        private
        def tnow
          Updater::Update.time.now.to_i
        end
      end #class << self
      
      attr_reader :id
      
      attr_accessor :time, :target, :finder, :finder_args, :method, :method_args, :name, :lock_name, :persistant
      
      def initialize(hash = {})
        @id = self.class.index
        hash.each do |k,v| 
          self.send("#{k}=",v)
        end
      end
      
      def lock(worker)
        return false if @lock_name && @lock_name != worker.name
        @lock_name = worker.name
      end
      
      def save
        self.class.storage[id] = self
      end
      
      def destroy
        self.class.storage.delete(id)
      end
      
      %w{failure success ensure}.each do |mode|
        eval(<<-EOF, binding ,__FILE__, __LINE__+1)
          def #{mode}
            @#{mode} ||= []
          end
          
          def #{mode}=(chain)
            @#{mode} ||= []
            mchain = chain.kind_of?(Array) ? chain : [chain]
            @#{mode} += mchain.map { |x| rationalize_instance(x) }.flatten
            # attach_intellegent_insertion(@#{mode},:#{mode},self) if @#{mode}
            chain
          end
        EOF
      end
      
      private
      
      def rationalize_instance(val)
        case val
          when Updater::Update
            val
          when self.class
            Updater::Update.new(val)
          when Integer
            Updater::Update.new(self.class.storage[val])
          when Hash
            val.map do |target, params|
              rationalize_instance(target).tap{|u| u.params = params}
            end
            
        end
      end
      
    end
  end
end