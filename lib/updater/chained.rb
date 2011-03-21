module Updater
  class Chained
    class << self
      def jobs(name)
        name = name.to_s
        @jobs ||= Hash.new {|_,n| find_or_create(n)}
        @jobs[name]
      end
      
      def reschedule(job,options)
        new_time = options[:at] || Update.time.now + options[:in]
        Update.at(
          new_time,job.target,job.method,job.method_args,
          :finder=>job.finder,
          :finder_args=>job.finder_args,
          :name=>job.name,
          :success=>job.success - [jobs(:reschedule)],
          :failure=>job.failure - [jobs(:reschedule)],
          :ensure=>job.ensure - [jobs(:reschedule)]
        )
      end
      
      def __reset
        @jobs = nil
        @args_for == {}
      end
      
      private
      
      def find_or_create(name)
        Update.for(self,name) || create(name)
      end
      
      def create(name)
        Update.chain(self,name,args_for[name]||[:__job__,:__params__],:name=>name)
      end
      
      def args_for
        @args_for ||= {}
      end
    end # class << self
  end # class Chained
end # module Update