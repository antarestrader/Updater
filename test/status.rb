

require "rubygems"

ROOT = File.join(File.dirname(__FILE__))
$LOAD_PATH << File.join(File.dirname(__FILE__), '../lib')

require "dm-core"
#require "dm-agragate"

require 'updater'
require 'updater/worker'

require File.join(ROOT, 'target.rb')

DataMapper.setup(:default, :adapter=>'sqlite3', :database=>File.join(ROOT, 'simulated.db'))

include Updater

puts "Update Status:"
puts "  Pending Updates: #{Update.delayed.count}"
puts "  Current Updates: #{Update.current.count}"
puts "  Time Range: #{Update.delayed.first(:order=>[:time.asc]).time - Time.now.to_i} .. #{Update.delayed.first(:order=>[:time.desc]).time - Time.now.to_i}"