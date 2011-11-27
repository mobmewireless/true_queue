
require 'redis'
require 'yajl'

module MobME
  module Infrastructure
    module RedisQueue
    end
  end
end

require_relative 'redis_queue/exceptions'
require_relative 'redis_queue/backend/redis'
