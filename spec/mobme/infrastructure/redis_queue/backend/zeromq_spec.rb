require_relative '../../../../spec_helper'
require_relative 'queue_behavior'

describe MobME::Infrastructure::RedisQueue::Backends::ZeroMQ do
  let(:queue) { MobME::Infrastructure::RedisQueue.queue(:zeromq) }
  
  describe "#add" do
    it "adds a simple value to a queue" do
      EM.synchrony do
        queue.add "queue", 1
        
        EM.add_timer(1) { EM.stop }
      end
    end
  end
end
