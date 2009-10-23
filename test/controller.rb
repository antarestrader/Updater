pid = ARGV[0]

begin
  pid = Integer("#{ pid }")
  Process::kill 0, pid
rescue Errno::ESRCH, ArgumentError
  puts "please provide a valid PID as the first arg"
  puts " got #{pid || 'nil' }"
  exit 1
end

puts "Controlling process #{pid}"

require "rubygems"

ROOT = File.join(File.dirname(__FILE__))
$LOAD_PATH << File.join(File.dirname(__FILE__), '../lib')

require "dm-core"

require 'updater'
require 'updater/worker'

require File.join(ROOT, 'target.rb')

DataMapper.setup(:default, :adapter=>'sqlite3', :database=>File.join(ROOT, 'simulated.db'))

include Updater
Update.pid = pid

def add(time)
  errored = false
  Update.at(Time.now + time, Target,:method1)
rescue DataObjects::ConnectionError
  raise if errored
  errored = true
  sleep 0.1
  retry
end

add(0)
add(1)
add(8)
add(3)

