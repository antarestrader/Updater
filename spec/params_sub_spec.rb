require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

require  File.join( File.dirname(__FILE__),  "fooclass" )

describe "Special Parameter Substitution" do
  it "should substitute __job__ with job"
  
  it "should substitute __params__ with params" 
  
end