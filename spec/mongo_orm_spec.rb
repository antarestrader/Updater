require File.join( File.dirname(__FILE__),  "spec_helper" )
require 'updater/orm/mongo'

describe Updater::ORM::Mongo do
  it_behaves_like "an orm", :database=>'test'
  
end