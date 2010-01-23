require 'updater'

class Target
  include Updater
  class << self
    def method1
      @m1 ||=0
      @m1 += 1
      puts "Method 1 called. (#{@m1}) t=#{ts}"
    end
    
    SIM_WORK= {
      "initial" => 0.0,
      "Short" => 0.0,
      "Intermitent"=> 15.0,
      "Medium"=> 5.0,
      "Long"=>30.0
    }
    
    def spawner(cnt = 0, str="initial")
      puts "Spawner called at #{ts} (#{str} #{cnt})"
      load = Update.current.count
      sleep SIM_WORK[str] || 0.0 unless load > 100 #simulating work
      puts " delay: #{Update.delayed.count} current: #{Update.current.count}"
      if cnt <= 5
        add(7 +(rand 20),cnt+1,"Short") unless load > 20
        add(30+(rand 500),cnt+1,"Intermitent") # 30 + r500
        add(60 + (rand 12)*15,cnt+1,"Medium")
        add(300 + (rand 7)*60,cnt+1,"Long")
      end
    end
    
    def add(time,cnt, string)
      errored = false
      Update.at(Update.time.now + time, Target,:spawner,[cnt,string])
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