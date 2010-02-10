require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

require  File.join( File.dirname(__FILE__),  "fooclass" )

describe "Special Parameter Substitution" do
  before :each do
    Update.clear_all
    @u = Update.chain(Foo,:chained, [:__job__,:__params__,:__self__, 'job params'])
  end
  
  it "should substitute __job__ with job that chained in" do
    Foo.should_receive(:chained).with(:arg1,anything(),anything(),'job params')
    @u.run(:arg1)
  end
  
  it "should substitute __params__ with params" do
    Foo.should_receive(:chained).with(anything(),:arg2,anything(), 'job params')
    @u.run(:arg1,:arg2)
  end
  
  it "should substitute __self__ with the current job" do
    Foo.should_receive(:chained).with(anything(),anything(),@u, 'job params')
    @u.run
  end
end