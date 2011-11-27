
shared_examples_for "a queue" do
  describe "#add" do
    it "adds a simple value to a queue" do
      queue.add "queue", 1
    end
    
    it "adds a complex value to a queue" do
      queue.add "queue", Time.now
    end
    
    context "with priority" do
      it "adds a value with priority set to the queue" do
        queue.add "queue", "hello", {'priority' => 1}
      end
      
      it "only accepts priority between 1 and 100" do
        lambda { queue.add "queue", "hello", {'priority' => 0} }.should raise_error ArgumentError
        lambda { queue.add "queue", "hello", {'priority' => 101} }.should raise_error ArgumentError
      end
    end
    
    context "with dequeue-timestamp" do
      it "adds an item with a dequeue timestamp set to the queue" do
        queue.add "queue", "hello", {'dequeue-timestamp' => Time.now + 1}
      end
      
      it "only accepts valid Time objects as timestamps" do
        lambda { queue.add "queue", "hello", {'dequeue-timestamp' => 1} }.should raise_error ArgumentError
      end
    end
  end
  
  describe "#remove" do
    before(:each) { queue.empty "queue" }
    
    it "can remove a simple value from the queue" do
      queue.add "queue", 1
      (queue.remove "queue").should == [1, {}]
    end
    
    it "should remove nil from an empty queue" do
      (queue.remove "queue").should == nil
    end
    
    it "can remove a complex value from the queue" do
      queue.add "queue", Time.now
      
      item = (queue.remove "queue")
      (Time.now - DateTime.strptime(item[0], "%Y-%m-%d %H:%M:%S %Z").to_time).should < 1
    end
    
    context "with priority" do
      it "removes values from queue according to the priority set" do
        queue.add "queue", "hello", {'priority' => 1}
        queue.add "queue", "world", {'priority' => 2}
        queue.add "queue", "vishnu"
        
        (queue.remove "queue").should == ["world", {'priority' => 2}]
        (queue.remove "queue").should == ["hello", {'priority' => 1}]
        (queue.remove "queue").should == ["vishnu", {}]
      end
    end
    
    context "with dequeue-timestamp" do
      it "delays retrieval of items until the dequeue-timestamp has come and gone" do
        future_time = Time.now + 1
        
        queue.add "queue", "thrift"
        queue.add "queue", "pincer", {'dequeue-timestamp' => future_time}
        
        (queue.remove "queue").should == ["thrift", {}]
        (queue.remove "queue").should == nil
        sleep 1
        (queue.remove "queue").should == ["pincer", {'dequeue-timestamp' => future_time.to_s }]
      end
    end
    
    context "with a block given" do
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
          raise MobME::Infrastructure::RedisQueueRemoveAbort
        end
        (queue.peek "queue").should == ["pincer", {'priority' => 2}]
      end
    end
  end
  
  describe "#peek" do
    before(:each) { queue.empty "queue" }
    
    it "can look at the first element of a queue without removing it" do
      queue.add "queue", "hello"
      (queue.peek "queue").should == ["hello", {}]
      (queue.peek "queue").should == ["hello", {}]
      queue.remove "queue"
      (queue.peek "queue").should == nil
    end
  end
  
  describe "#list" do
    before(:each) { queue.empty "queue" }
    
    it "works with small queues" do
      queue.add "queue", "hello"
      queue.add "queue", "hello2"
      queue.add "queue", "hello2", {'priority' => 3}
      
      (queue.list "queue").should == [["hello2", {"priority"=>3}], ["hello", {}], ["hello2", {}]]
    end
    
    it "works with larger queues" do
      10_000.times do |i|
        queue.add "queue", "hello #{i}"
      end
      
      (queue.list "queue").length.should == 10_000
    end
  end
  
  describe "#size" do
    before(:each) { queue.empty "queue" }
    
    it "can look at the first element of a queue without removing it" do
      queue.add "queue", "hello"
      queue.add "queue", "hello2"
      queue.add "queue", "hello2", {'priority' => 3}
            
      (queue.size "queue").should == 3
    end
  end
  
  describe "#empty" do
    it "empties the queue" do
      queue.add "queue", "hello", {'priority' => 1}
      queue.add "queue", "world", {'priority' => 2}
      queue.add "queue", "thrift"
      queue.add "queue", "pincer", {'dequeue-timestamp' => Time.now}
      
      queue.empty "queue"
      
      (queue.remove "queue").should == nil
    end
  end
  
  describe "#list_queues" do
    before(:each) do
      queue.remove_queues
    end
    
    it "lists all queues" do
      queue.add "queue", "thrift"
      queue.add "queue2", "thrift"
      queue.add "queue3", "pincer", {'dequeue-timestamp' => Time.now}
      
      queue.list_queues.should include "queue", "queue2", "queue3"
      queue.list_queues.length.should == 3
    end
  end
  
  describe "#remove_queues" do
    before(:each) do
      queue.add "queue", "thrift"
      queue.add "queue2", "thrift"
      queue.add "queue3", "pincer", {'dequeue-timestamp' => Time.now}
    end
    
    it "deletes named queues" do      
      queue.remove_queue "queue"
      queue.list_queues.should include("queue2")
      queue.list_queues.should include("queue3")
      queue.list_queues.should_not include("queue")
    end
    
    it "deletes multiple named queues" do
      queue.remove_queues "queue", "queue2"
      queue.list_queues.should include("queue3")
      queue.list_queues.should_not include("queue")
      queue.list_queues.should_not include("queue2")
    end
    
    it "can delete every queue" do
      queue.remove_queues
      queue.list_queues.should_not include("queue3")
      queue.list_queues.should_not include("queue")
      queue.list_queues.should_not include("queue2")
    end
  end
end