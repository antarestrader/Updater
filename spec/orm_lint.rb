shared_examples_for "an orm" do |test_setup|
  
  before :each do
    @target = Foo.create
    @opts = {
      :time =>Updater::Update.time.now.to_i, 
      :target=>Foo, :finder=>'find', :finder_args=>[@target.id],
      :method=>'bar', :method_args=>['baz'],
      :persistant=>false
    }
  end
  
  let(:instance) { described_class.create(@opts) }
  let(:delayed) { described_class.create(@opts.merge(:time =>Updater::Update.time.now.to_i + 25000)) }
  ["","1","2","3"].each do |c|
    let("chained#{c}".to_sym) { Updater::Update.new(described_class.create(@opts.merge(:time =>nil, :persistant=>true))) }
  end
  %w{tom dick harry}.each do |name|
    let("#{name}_job".to_sym) { Updater::Update.new(described_class.create(@opts.merge(:name=>name))) }
  end
  
  before :all do
    test_setup ||= {}
    test_setup[:logger] ||= Logger.new(STDOUT).tap {|l| l.level = 99}
    described_class.setup(test_setup)
    @old_orm = Updater::Update.orm
    Updater::Update.orm = described_class
  end
  
  after :all do
    Updater::Update.orm = @old_orm
  end
  
  #Class Methods
  describe "class methods" do
    %w{get create current current_load delayed future queue_time lock_next clear_locks 
    clear_all setup for logger logger=}.each do |m|
      it "should have a class method: #{m}" do
        described_class.should respond_to(m)
      end
    end
  end
  
  describe "instance methods" do
    %w{id time time= target target= finder finder= finder_args finder_args= 
       method method= method_args method_args= name name= persistant persistant= 
       save destroy lock}.each do |m|
      it "should have an instance method: #{m}" do
        instance.should respond_to(m)
      end
    end
  end
  
  describe "constants" do
    %w{FINDER ID}.each do |c|
      it "should have a constant: #{c}" do
        described_class.const_get(c).should be_kind_of Symbol
      end
    end
  end
  
  
  
  describe "clear_all" do
    it "should remove all jobs" do
      described_class.clear_all
      (described_class.current_load + described_class.delayed).should == 0
    end
  end
  
  describe "an instance" do
    before :each do
      described_class.clear_all
      instance
    end
    
    it "should have an id" do
      instance.id.should_not be_nil
    end
    
    describe "getters" do
      %w{time finder finder_args method method_args target persistant}.each do |m|
        specify "#{m} should be set to the correct value" do
          instance.send(m.to_s).should == @opts[m.to_sym]
        end
      end
    end
    
    it "should be in the current list" do
      described_class.current.should include(instance)
      described_class.current_load.should == 1
    end
    
    it "should be retrieved with 'get'" do
      described_class.get(instance.id).should == instance
    end
    
    it "should be removed with 'destroy'" do
      instance.destroy
      described_class.get(instance.id).should be_nil
      described_class.current_load.should == 0
    end
    
  end
    
  describe "locking" do    
    before :each do
      @worker1 = Struct.new(:name).new('foo')
      @worker2 = Struct.new(:name).new('bar')
      @worker1.stub(:say)
      @worker2.stub(:say)
    end
    
    it "an instance should lock" do
      instance.lock(@worker1).should be_true
    end
    
    it "an instance should lock again with the same worker" do
      instance.lock(@worker1).should be_true
      instance.lock(@worker1).should be_true
    end
    
    it "an instance should lock if it has been locked" do
      instance.lock(@worker1).should be_true
      instance.lock(@worker2).should be_false
    end
  end
  
  describe "lock_next" do
    before :each do
      described_class.clear_all
      @worker1 = Struct.new(:name).new('foo')
      @worker2 = Struct.new(:name).new('bar')
      @worker1.stub(:say)
      @worker2.stub(:say)
    end
    
    it "should return the next current instance locked to the worker" do
      instance
      job = described_class.lock_next(@worker1)
      job.should == instance
      job.lock(@worker2).should be_false
    end
    
    it "should return nil if there are no current jobs without a lock" do
      described_class.lock_next(@worker1).should be_nil
      delayed
      described_class.lock_next(@worker1).should be_nil
      instance.lock(@worker2)
      described_class.lock_next(@worker1).should be_nil
    end
    
  end
  
  describe "clear locks" do
    before :each do
      described_class.clear_all
      @worker1 = Struct.new(:name).new('foo')
      @worker2 = Struct.new(:name).new('bar')
      @worker1.stub(:say)
      @worker2.stub(:say)
    end
    
    it "should clear every lock held by a worker" do
      instance.lock(@worker1)
      described_class.clear_locks(@worker1)
      instance.lock(@worker2).should be_true
    end
  end
  
  describe "queue_time" do
    before :each do
      described_class.clear_all
    end
    
    it "should be nil if the queue is empty" do
      described_class.queue_time.should be_nil
    end
    
    it "should be 0 if there is a current job" do
      instance
      described_class.queue_time.should == 0
    end
    
    it "should be the time to the next job" do
      Timecop.freeze do
        delayed
        described_class.queue_time.should == 25000
      end
    end
  end
  
  describe "with method chaining:" do
    before :each do
      described_class.clear_all
    end
    
    %w{success failure ensure}.each do |mode|
      describe mode  do
        it "should initially be empty" do
          instance.send(mode).should be_empty
        end
      end
      describe "#{mode}=" do
        it "should add an Update instance" do
          instance.send("#{mode}=", chained).should == chained
          instance.send(mode).should_not be_empty
          instance.send(mode).should include chained
        end
        
        it "should add a #{described_class.to_s} instance" do
          instance.send("#{mode}=", chained.orm).should == chained.orm
          instance.send(mode).should_not be_empty
          instance.send(mode).map{|x| x.orm}.should include chained.orm
        end
        
        it "should add an id" do
          instance.send("#{mode}=", chained.id).should == chained.id
          instance.send(mode).should_not be_empty
          instance.send(mode).should include chained
        end
        
        it "should add multiple items from an array" do
          instance.send("#{mode}=", [chained,chained1,chained2])
          instance.send(mode).length.should == 3
          instance.send(mode).should == [chained,chained1,chained2]
        end
        
        specify "nested arrays should set param" do
          instance.send("#{mode}=", [chained,[chained1, :foo],chained2])
          puts "%s (%s:%s)" % [instance.send(mode),__FILE__,__LINE__] if instance.send(mode)[1].nil?
          instance.send(mode)[1].params.should == :foo
        end
        
        it "should add multiple items from a hash" do
          instance.send("#{mode}=", {chained=>:foo,chained1=>:bar,chained2=>:baz})
          instance.send(mode).length.should == 3
          instance.send(mode).should == [chained,chained1,chained2]
        end
        
        it "should set the parameters from a hash" do
          instance.send("#{mode}=", {chained=>:foo})
          instance.send(mode)[0].params.should == :foo
        end
        
        it "should clear the chain with nil" do
          instance.send("#{mode}=", [chained,chained1,chained2])
          instance.send(mode).length.should == 3
          instance.send("#{mode}=", nil).should be_nil
          instance.send(mode).length.should == 0
        end
        
        it "should NOT be a destructive assignment" do
          instance.send("#{mode}=", [chained,chained1,chained2])
          instance.send(mode).length.should == 3
          instance.send("#{mode}=", {chained3=>:foo})
          instance.send(mode).length.should == 4
          instance.send(mode)[3].should == chained3
        end
 
      end # mode=
    end # {success, failure, ensure}
  end #chaining
  
  describe " #for" do
    before :each do
      described_class.clear_all
      tom_job; dick_job; harry_job
    end
      
    it "should find all jobs" do
      described_class.for(@target.class, @opts[:finder], [@target.id]).should include(tom_job.orm, dick_job.orm, harry_job.orm)
    end
    
    it "should find a job by name" do
      described_class.for(@target.class, @opts[:finder], [@target.id], "dick").first.should == dick_job.orm
    end
    
    it "should return an empty array if no job is found" do
      foo = Foo.create
      described_class.for(@target.class, @opts[:finder], [@target.id], "john").should be_empty
      described_class.for(@target.class, @opts[:finder], [foo.id]).should be_empty
    end
    
    it "should not return a locked record" do
      described_class.for(@target.class, @opts[:finder], [@target.id]).should include(tom_job.orm, dick_job.orm, harry_job.orm)
      tom_job.orm.lock(Struct.new(:name).new('test_worker'))
      described_class.for(@target.class, @opts[:finder], [@target.id]).should_not include(tom_job.orm)
    end
    
  end #for
end