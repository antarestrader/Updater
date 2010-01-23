class GT #Game Time
  attr_reader :running
  def start
    @running = true
    @epoc = Time.now
    now
  end
  
  def stop
    @accl = now
    @running = false
    @accl
  end
  
  def now
    if @running
      (Time.now - @epoc).to_i + @accl
    else
      @accl
    end
  end
  
  def toggle
    @running ? stop : start
  end
  
  def initialize
    @accl = 0
  end
 
end

