require 'updater'

class Target
  include Updater
  class << self
    include Updater
    
    def socket=(s)
      @socket = s
    end
    
    def socket
      @socket ||= open_socket
    end
    
    def open_socket
      socket = UNIXSocket.open(File.join(File.dirname(__FILE__),'cascade.sock'))
      socket.puts "Target.rb:18 has opened socket pid: #{Process.pid}"
      socket
    end
    
    def error_reporter(job)
      Update.logger.info "#{[__FILE__,__LINE__].join(':')} -- #{job.error.inspect}\n||=========\n|| Backtrace\n|| " + job.error.backtrace.join("\n|| ") + "\n||========="
      socket.puts job.error.inspect
    end
    
    def method1
      @m1 ||=0
      @m1 += 1
      socket.puts "Method 1 called. (#{@m1}) t=#{ts}"
    end
    
    def chain(job,params)
      socket.puts "Job #{job.name || job.id} chained in."
    end
    
    def reschedule(job,delay)
      
    end
    
    SIM_WORK= {
      "initial" => 0.0,
      "Short" => 0.0,
      "Intermitent"=> 15.0,
      "Medium"=> 5.0,
      "Long"=>30.0
    }
    
    def spawner(cnt = 0, str="initial")
      socket.puts "Spawner called at #{ts} (#{str} #{cnt})"
      load = Update.load
      sleep SIM_WORK[str] || 0.0 unless load > 100 #simulating work
      socket.puts " delay: #{Update.delayed} current: #{Update.load} antisipated: #{Update.future(60)}"
      if cnt <= 5
        add(7 +(rand 5),cnt+1,"Short") unless load > 20 #was 30
        add(30+(rand 500),cnt+1,"Intermitent") # 30 + r500
        add(5 + (rand 12)*15,cnt+1,"Medium") #was 60
        add(300 + (rand 7)*60,cnt+1,"Long")
      end
    end
    
    def add(time,cnt, string)
      errored = false
      Update.in(time, Target,:spawner,[cnt,string])
    rescue DataObjects::ConnectionError
      raise if errored
      errored = true
      sleep 0.1
      retry
    end
    
    def ts
      Time.now.strftime("%H:%M:%S")
    end
  end
end