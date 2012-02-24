
shared_examples_for "a reserved queue" do
  describe "#remove" do
    it "passes items into the block" do
      queue.add "queue", "thrift"
      queue.remove "queue" do |item|
        item.should == ["thrift", {}]
      end
    end
  
    it "passes items with metadata into the block" do
      queue.add "queue", "pincer", {'priority' => 2}
      queue.remove "queue" do |item|
        item.should == ["pincer", {'priority' => 2}]
      end
    end
  
    it "can reserve items and re-add them when an error occurs" do
      queue.add "queue", "pincer", {'priority' => 2}
      queue.add "queue", "thrift", {'priority' => 1}
    
      # Make an exception here
      lambda do
        queue.remove "queue" do |item|
          1 / 0
        end
      end.should raise_error ZeroDivisionError
      (queue.peek "queue").should == ["pincer", {'priority' => 2}]
    end
  
    it "can reserve items and re-add them when a manual abort is triggered" do
      queue.add "queue", "pincer", {'priority' => 2}
      queue.add "queue", "thrift", {'priority' => 1}
    
      # Manually abort the operation here
      queue.remove "queue" do |item|
        raise TrueQueue::RemoveAbort
      end
      (queue.peek "queue").should == ["pincer", {'priority' => 2}]
    end
  end
end