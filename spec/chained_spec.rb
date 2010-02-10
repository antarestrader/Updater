require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

require  File.join( File.dirname(__FILE__),  "fooclass" )

describe "Adding Chained Methods:" do
  
  before :each do
    Update.clear_all
    Foo.all.destroy!
    @u = Update.chain(Foo,:chained,[:__job__,:__params__])
  end
  
  [:failure, :success, :ensure].each do |mode|
    specify "adding '#{mode.to_s}' chain" do
      v = Update.immidiate(Foo,:method1,[],mode=>@u)
      v.orm.send(mode).should_not be_nil
    end
  end
  
end