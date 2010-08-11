#!/usr/local/bin/ruby

#this file sets up a basic Updater setup so that signals can be hand tested

require "rubygems"
require "ruby-debug"

ROOT = File.join(File.dirname(__FILE__))
$LOAD_PATH << File.join(ROOT, '../lib')

require 'updater'
require 'updater/setup'
require 'updater/thread_worker'
require File.expand_path(File.join(ROOT,'cascade/target.rb'))

Target.socket = STDOUT

include Updater

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

logger.warn "Start"
logger.debug "Logger in Debug Mode"

worker = ThreadWorker.new :name=>'worker'

Setup.client_setup :orm=>'mongodb', :logger=>logger
Update.orm.setup :database=>'test', :logger=>logger

Update.clear_all

err_rpt = Updater::Update.chain(Target,:error_reporter,[:__job__])
err_rpt.params = {:foo=>:bar}

Update.in(20*60,Target, :method1,[], :failure=>err_rpt)

h = Update.orm.collection.find_one(:time=>{'$exists'=>true})
u = Update.orm.new(h)
debugger
fs = u.failure


t = Update.orm.queue_time
Update.work_off(worker)

logger.warn "Finished"
