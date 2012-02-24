require_relative '../../../../spec_helper'
require_relative 'queue_behavior'

require 'mobme/infrastructure/queue/backends/amqp'

describe TrueQueue::Backends::AMQP do
    
  let(:queue) { TrueQueue.queue(:amqp) }
  
  describe "#add" do
    before(:each) { queue.empty "queue" }
    
    it "adds a simple value to a queue" do
      queue.add "queue", 1
    end
    
    it "adds a complex value to a queue" do
      queue.add "queue", Time.now
    end    
  end
  
  describe "#add_bulk" do
    before(:each) { queue.empty "queue" }
    
    it "can add multiple items passed in to a queue" do
      items = []
      100.times do |i|
        items << i
      end
      
      # Now add in bulk
      queue.add_bulk "queue", items
      
      returned_items = []
      100.times do |i|
        returned_items << (queue.remove "queue")
      end
      
      # Just check for the items, not the metadata
      returned_items.map { |item| item[0] }.should == items
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
  end
  
  describe "#size" do
    before(:each) { queue.empty "queue" }
    
    it "can return the size of the queue" do
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
