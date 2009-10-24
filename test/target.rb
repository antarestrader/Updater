require 'updater'

class Target
  include Updater
  class << self
    def method1
      @m1 ||=0
      @m1 += 1
      puts "Method 1 called. (#{@m1}) t=#{ts}"
    end
    
    def spawner(cnt = 0, str="initial")
      puts "Spawner called at #{ts} (#{str} #{cnt})"
      #sleep 1.0 #simulating work
      puts " delay: #{Update.delayed.count} current: #{Update.current.count}"
      if cnt <= 5
        add(7 +(rand 120),cnt+1,"Short")
        add(30 +(rand 500),cnt+1,"Intermitent")
        add(60 + (rand 12)*15,cnt+1,"Medium")
        add(300 + (rand 7)*60,cnt+1,"Long")
      end
    end
    
    def add(time,cnt, string)
      errored = false
      Update.at(Time.now + time, Target,:spawner,[cnt,string])
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