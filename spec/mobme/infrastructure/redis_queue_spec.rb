require_relative '../../spec_helper'
require_relative 'queue_behavior'

puts "Specs require a Redis client running on the default port."

describe MobME::Infrastructure::RedisQueue do
  let(:queue) { MobME::Infrastructure::RedisQueue.new }
  
  it_behaves_like "a queue"
end
