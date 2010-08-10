#!/usr/local/bin/ruby

#this file sets up a basic Updater setup so that signals can be hand tested

require "rubygems"
require "ruby-debug"

ROOT = File.join(File.dirname(__FILE__))
$LOAD_PATH << File.join(ROOT, '../lib')

require 'updater'
require 'updater/setup'
require 'updater/thread_worker'

include Updater

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

logger.warn "Start"
logger.debug "Logger in Debug Mode"

worker = ThreadWorker.new :name=>'worker'

Setup.client_setup :orm=>'mongodb', :logger=>logger
Update.orm.setup :database=>'test', :logger=>logger

Update.clear_all

debugger

logger.warn "Finished"
