puts Process.pid

QUEUE_SIGS = [:ALRM,:QUIT, :INT, :TERM, :USR1, :USR2, :HUP,
                   :TTIN, :TTOU]



def trap_deferred(signal)
  trap(signal) do |sig|
    puts "caught #{signal.inspect}"
    exit if signal == :TERM
  end
end

QUEUE_SIGS.each { |sig| trap_deferred(sig) }

while true
  sleep
end