#!/usr/local/bin/ruby

#this file sets up a basic Updater setup so that signals can be hand tested

require "rubygems"

ROOT = File.join(File.dirname(__FILE__))
$LOAD_PATH << File.join(File.dirname(__FILE__), '../lib')

require "dm-core"

require 'updater'
require 'updater/worker'

require File.join(ROOT, 'target.rb')

DataMapper.setup(:default, :adapter=>'sqlite3', :database=>File.join(ROOT, 'simulated.db'))
DataMapper.auto_upgrade!
include Updater


Update.immidiate(Target,:method1)
Update.at(Time.now + 5, Target,:method1)

Update.pid = Process.pid

trap('USR2') do
  puts "Beginnign Cascade" 
  Update.immidiate(Target,:spawner)
end

Worker.new.start
