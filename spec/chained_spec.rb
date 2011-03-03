require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

require  File.join( File.dirname(__FILE__),  "fooclass" )

describe "Chained Methods:" do
  
  before :each do
    Update.clear_all
    Foo.reset
    pending "ORM Chaining not yet tested"
    @u = Update.chain(Foo,:chained,[:__job__,:__params__])
    @v = Update.chain(Foo,:chained2,[:__job__,:__params__])
    #pending "Chained Worker not implimented in datamapper,  Waiting form ORM code refactor"
  end
  
  [:failure, :success, :ensure].each do |mode|
    specify "adding '#{mode.to_s}' chain" do
      v = Update.immidiate(Foo,:method1,[],mode=>@u)
      v.orm.send(mode).should_not be_empty
    end
  end
  
  specify "'failure' should run after an error" do
    v = Update.immidiate(Foo,:method1,[],:failure=>@u)
    Foo.should_receive(:method1).and_raise(RuntimeError)
    Foo.should_receive(:chained).with(v,anything())
    v.run
  end
  
  specify "'failure' should NOT run if their is no error" do
    v = Update.immidiate(Foo,:method1,[],:failure=>@u)
    Foo.should_receive(:method1).and_return(:anything)
    Foo.should_not_receive(:chained)
    v.run
  end
  
  specify "'success' should NOT run after an error" do
    v = Update.immidiate(Foo,:method1,[],:success=>@u)
    Foo.should_receive(:method1).and_raise(RuntimeError)
    Foo.should_not_receive(:chained)
    v.run
  end
  
  specify "'success' should run if their is no error" do
    v = Update.immidiate(Foo,:method1,[],:success=>@u)
    Foo.should_receive(:method1).and_return(:anything)
    Foo.should_receive(:chained).with(v,anything())
    v.run
  end
  
  specify "'ensure' should run after an error" do
    v = Update.immidiate(Foo,:method1,[],:ensure=>@u)
    Foo.should_receive(:method1).and_raise(RuntimeError)
    Foo.should_receive(:chained).with(v,anything())
    v.run
  end
  
  specify "'ensure' should run if their is no error" do
    v = Update.immidiate(Foo,:method1,[],:ensure=>@u)
    Foo.should_receive(:method1).and_return(:anything)
    Foo.should_receive(:chained).with(v,anything())
    v.run
  end
  
  specify "params should be availible" do
    v = Update.immidiate(Foo,:method1,[],:ensure=>{@u=>'hi', @v=>'bye'})
    Foo.should_receive(:method1).and_return(:anything)
    Foo.should_receive(:chained).with(anything(), 'hi')
    Foo.should_receive(:chained2).with(anything(), 'bye')
    v.run
  end
  
  specify "add an Array" do
    v = Update.immidiate(Foo,:method1,[],:ensure=>[@u,@v])
    Foo.should_receive(:method1).and_return(:anything)
    Foo.should_receive(:chained).with(anything(), anything())
    Foo.should_receive(:chained2).with(anything(), anything())
    v.run
  end
  
end