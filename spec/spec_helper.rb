require "rubygems"

ROOT = File.join(File.dirname(__FILE__), '..')

require "spec" # Satisfies Autotest and anyone else not using the Rake tasks
require "dm-core"

require File.join(ROOT, 'lib','updater')

DataMapper.setup(:default, 'sqlite3::memory:')
DataMapper.auto_migrate!

require 'timecop'
require 'chronic'

