require_relative '../../../../spec_helper'
require_relative 'queue_behavior'

require 'mobme/infrastructure/queue/backends/zeromq'

describe TrueQueue::Backends::ZeroMQ do
  around(:each) do |example|
    EM.synchrony do
      example.run
      
      EM.add_timer(0.2) { EM.stop }
    end
  end
  
  let(:queue) { TrueQueue.queue(:zeromq) }
  
  it_behaves_like "a queue"
end
