require_relative '../../../../spec_helper'
require_relative 'queue_behavior'
require_relative 'reserved_queue_behavior'

require 'mobme/infrastructure/queue/backends/memory'

describe MobME::Infrastructure::Queue::Backends::Memory do
  let(:queue) { MobME::Infrastructure::Queue.queue(:memory) }
  
  it_behaves_like "a queue"
  it_behaves_like "a reserved queue"
end
