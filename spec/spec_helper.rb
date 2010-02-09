require "rubygems"

ROOT = File.join(File.dirname(__FILE__), '..')
$LOAD_PATH << File.join(File.dirname(__FILE__), '../lib')

require "spec" # Satisfies Autotest and anyone else not using the Rake tasks
require "dm-core"

require 'updater'
require 'updater/thread_worker'
require 'updater/fork_worker'
require 'updater/orm/datamapper'

Updater::Update.orm = Updater::ORM::DataMapper

DataMapper.setup(:default, 'sqlite3::memory:')
DataMapper.auto_migrate!

require 'timecop'
require 'chronic'


