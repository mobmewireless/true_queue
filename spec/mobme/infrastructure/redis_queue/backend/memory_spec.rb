require_relative '../../../../spec_helper'
require_relative 'queue_behavior'

describe MobME::Infrastructure::RedisQueue::Backends::Memory do
  let(:queue) { MobME::Infrastructure::RedisQueue.queue(:memory) }
  
  it_behaves_like "a queue"
end
