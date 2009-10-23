# This file based the file of the same name in the delayed_job gem by
# Tobias Luetke (Coypright (c) 2005) under the MIT License.

require 'benchmark'

module Updater

  #This class repeatedly searches the database for active jobs and runs them
  class Worker
    cattr_accessor :logger
    attr_accessor :pid
    attr_accessor :name
    
    def initialize(options={})
      @quiet = options[:quiet]
      @name = options[:name] || "host:#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"
      @pid = Process.pid
    end
    
    def start
      say "*** Starting job worker #{@name}"
      @t = run_job_loop
      
      trap('TERM') { terminate_with @t }
      trap('INT')  { terminate_with @t }
      
      trap('USR1') do
        old_proc = trap('USR1','IGNORE')
        say "Wakeup Signal Caught"
        run_loop
        trap('USR1',old_proc)
      end
      
      Thread.pass
     
      sleep unless $exit
    end
    
    def say(text)
      puts text unless @quiet
      logger.info text if logger      
    end
    
    def clear_locks
      Update.all(:lock_name=>@name).update(:lock_name=>nil) 
    end
    
    def stop
      raise RuntimeError unless @t
      terminate_with @t
    end
    
    def run_loop
      if @t.alive?
        @t.run
      else
        say " ~~ Restarting Job Loop"
        @t = run_job_loop
      end
    end
    
  private
  
    def run_job_loop
      Thread.new do
        loop do
          delay = Update.work_off(self)
          break if $exit
          if delay 
            sleep delay 
          else
            sleep
          end
          break if $exit
        end
        say "Worker thread exiting!"
        clear_locks
      end
    end
  
    def terminate_with(t)
      say "Exiting..."
      $exit = true
      t.run if t.alive?
      say "Forcing Shutdown" unless status = t.join(15) #Nasty inline assignment
      clear_locks
      exit status ? 0 : 1
    end
  end
  
end