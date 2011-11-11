require_relative '../../spec_helper'

puts "Specs require a Redis client running on the default port."

describe MobME::Infrastructure::RedisQueue do
  let(:queue) { MobME::Infrastructure::RedisQueue.new }
  
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
    before(:each) { queue.clear "queue" }
    
    it "can remove a simple value from the queue" do
      queue.add "queue", 1
      (queue.remove "queue").should == [1, {}]
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
  end
  
  describe "#clear" do
    it "empties the queue" do
      queue.add "queue", "hello", {'priority' => 1}
      queue.add "queue", "world", {'priority' => 2}
      queue.add "queue", "thrift"
      queue.add "queue", "pincer", {'dequeue-timestamp' => Time.now}
      
      queue.clear "queue"
      
      (queue.remove "queue").should == nil
    end
  end
  
  describe "#list_queues" do
    it "lists all queues" do
      queue.add "queue", "thrift"
      queue.add "queue2", "thrift"
      queue.add "queue3", "pincer", {'dequeue-timestamp' => Time.now}
      
      queue.list_queues.should include "queue", "queue2", "queue3"
      queue.list_queues.length.should == 3
    end
  end
end
