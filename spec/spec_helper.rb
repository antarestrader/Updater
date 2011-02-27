require "rubygems"

ROOT = File.join(File.dirname(__FILE__), '..')
$LOAD_PATH << File.join(File.dirname(__FILE__), '../lib')

require "rspec" # Satisfies Autotest and anyone else not using the Rake tasks
require "dm-core"
require 'dm-migrations'

require 'updater'
require 'updater/thread_worker'
require 'updater/fork_worker'
require 'updater/orm/datamapper'

Updater::Setup.test_setup(:database=>{:adapter=>'sqlite3', :database=>'./default.db', :auto_migrate=>true})

require 'timecop'
require 'chronic'
