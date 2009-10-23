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
DataMapper.auto_migrate!

include Updater

Update.immidiate(Target,:method1)
Update.at(Time.now + 5, Target,:method1)

trap('USR2') do
  puts "Scheduling Method1 for immidiate exicution" 
  Update.immidiate(Target,:method1)
end

Worker.new.start
