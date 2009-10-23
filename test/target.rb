class Target
  class << self
    def method1
      @m1 ||=0
      @m1 += 1
      puts "Method 1 called. (#{@m1}) t=#{Time.now.strftime("%H:%M:%S")}"
    end
  end
end