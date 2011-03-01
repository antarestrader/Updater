require File.join( File.dirname(__FILE__),  "spec_helper" )
require 'updater/orm/datamapper'

describe Updater::ORM::DataMapper do
  it_behaves_like "an orm", :adapter=>'sqlite3',:database=>':memory:',:auto_migrate=>true
  
end