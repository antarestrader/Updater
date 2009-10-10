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
      t = Thread.new do
        loop do
          delay = Update.work_off(self)
          break if $exit
          sleep delay
          break if exit
        end
      end
      
      trap('TERM') { terminate_with t }
      trap('INT')  { terminate_with t }
      
      trap('USR1') do
        say "Wakeup Signal Caught"
        t.run
      end
      
      sleep unless $exit
    end
    
    def say(text)
      puts text unless @quiet
      logger.info text if logger      
    end
    
  private
  
    def terminate_with(t)
      say "Exiting..."
      $exit = true
      t.run
      say "Forcing Shutdown" unless status = t.join(15) #Nasty inline assignment
      Update.clear_locks(self)
      exit status ? 0 : 1
    end
    
    
  end
  
end