require "rubygems"

require 'dm-core'
require 'dm-types'

module Updater
  VERSION = File.read(File.join(File.dirname(__FILE__),'..','VERSION')).strip
end

require 'updater/update.rb'