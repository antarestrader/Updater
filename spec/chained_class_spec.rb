require File.join( File.dirname(__FILE__),  "spec_helper" )

include Updater

describe Chained do
  before :each do
    Chained.__reset
    Update.clear_all
  end
  
  describe "reschedule:" do
    it "should return the job from #jobs" do
      reschedule = Chained.jobs(:reschedule)
      reschedule.should_not be_nil
      reschedule.method.should == "reschedule"
      reschedule.method_args.should == [:__job__,:__params__]
      reschedule.name.should == "reschedule"
    end
    
    it "should not schedule this job twice" do
      reschedule = Chained.jobs(:reschedule)
      Update.for(Chained).should == [reschedule]
      reschedule = Chained.jobs(:reschedule)
      Update.for(Chained).should == [reschedule]
    end
    
    it "should add an identical job back to the queue in the time spesified" do
      job = Update.immidiate(Foo,:bar,[],:name=>'testing')
      job.destroy #pretend it has alread run to completion
      reschedule = Chained.jobs(:reschedule)
      reschedule.params = {:in=>10}
      reschedule.run(job)
      reschedule.error.should be_nil
      new_job = Update.for(Foo, "testing")
      new_job.should_not be_nil
      new_job.time.should > job.time
    end
  end #describe "reschedule:" do

end