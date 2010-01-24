#!/usr/local/bin/ruby

#this file sets up a basic Updater setup so that signals can be hand tested

require "rubygems"
require "logger"

ROOT = File.join(File.dirname(__FILE__))
$LOAD_PATH << File.join(File.dirname(__FILE__), '../lib')

require "dm-core"

require 'updater'
require 'updater/fork_worker'
require 'updater/orm/datamapper'

require File.join(ROOT, 'target.rb')
#require File.join(ROOT, 'gt.rb')

DataMapper.setup(:default, :adapter=>'sqlite3', :database=>File.join(ROOT, 'simulated.db'))
DataMapper.auto_migrate!
include Updater

Update.orm = Updater::ORM::DataMapper

Update.immidiate(Target,:method1)
Update.at(Time.now + 5, Target,:spawner)
Update.at(Time.now + 5, Target,:method1)
Update.at(Time.now + 5, Target,:method1)
Update.at(Time.now + 5, Target,:method1)


Update.pid = Process.pid

trap('ALRM') do
  #$time.toggle
end

logger = Logger.new(STDOUT)
logger.level = Logger::INFO
ForkWorker.logger = logger

File.open("fork.pid",'w') {|f| f.write(Process.pid) }

if File.basename($0) == File.basename(__FILE__)
  ForkWorker.start(:foo, :timeout=>60, :workers=>10)
else
  ForkWorker.initial_setup(:timeout=>60, :workers=>10)
end
