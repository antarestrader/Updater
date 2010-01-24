require "rubygems"

module Updater
  VERSION = File.read(File.join(File.dirname(__FILE__),'..','VERSION')).strip
end

require 'updater/update.rb'