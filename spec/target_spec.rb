require File.join( File.dirname(__FILE__),  "spec_helper" )

require  File.join( File.dirname(__FILE__),  "fooclass" )

class Foo
  include Updater::Target
end

describe Updater::Target do
  before :each do
    @foo = Foo.create(:name=>"foo instance")
  end
  
  after :each do
    Updater::Update.clear_all
    Foo.reset
  end
  
  describe "#jobs_for" do
    specify "should not initially be any jobs for the target" do
      @foo.jobs_for.should be_empty
    end
    
    it "should contian all jobs regardless of how they got scheduled" do
      expected = []
      expected <<  @foo.enqueue(:bar)
      expected <<  @foo.send_in(600, :bar)
      expected <<  Updater::Update.in(1200, @foo, :bar)
      expected.each do |expectation|
        @foo.jobs_for.should include(expectation)
      end
    end
    
    it "should find a job by name" do
      @foo.enqueue(:bar)
      job = @foo.enqueue(:bar,[],:name=>"baz")
      @foo.send_in(600, :bar)
      Updater::Update.in(1200, @foo, :bar)
      @foo.job_for("baz").should == job
    end
  end
  
  describe "should schedual a job for the target instance" do
    
    specify "immidiatly with #send_later" do #compatibiltiy with delayed_job
      job = @foo.send_later :bar
      job.should be_a_kind_of Updater::Update
      job.target.should == @foo
      @foo.jobs_for.should == [job]
    end
    
    specify "immidiatly with #enqueue" do
      job = @foo.enqueue :bar
      job.should be_a_kind_of Updater::Update
      job.target.should == @foo
      @foo.jobs_for.should == [job]
    end
    
    specify "at a certian time with #send_at" do
      schedule_at = Time.now + 600
      job = @foo.send_at schedule_at , :bar
      job.target.should == @foo
      job.time.should == schedule_at.to_i
      @foo.jobs_for.should == [job]
    end
    
    specify "after a certian time with #send_in" do
      Timecop.freeze do
        job = @foo.send_in 600 , :bar
        job.target.should == @foo
        job.time.should == Time.now.to_i + 600
        @foo.jobs_for.should == [job]
      end
    end
  end
  
  describe "resetting default finder and id values: " do
    specify "finder" do
      Foo.updater_finder_method = :special_foo_finder
      job = @foo.enqueue :bar
      job.finder.should == :special_foo_finder
    end
    
    specify "id" do
      Foo.updater_id_method = :special_foo_identification
      @foo.should_receive(:special_foo_identification).and_return("razzle-dazzle")
      job = @foo.enqueue :bar
      job.finder_args.should == ["razzle-dazzle"]
    end
  
  end
end