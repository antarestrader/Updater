require File.join( File.dirname(__FILE__),  "spec_helper" )
require 'updater/orm/mock'

describe Updater::ORM::Mock do
  it_behaves_like "an orm"
  
end