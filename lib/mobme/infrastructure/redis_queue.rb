
require 'redis'
require 'yajl'

module MobME
  module Infrastructure
    module RedisQueue
      def self.queue(backend, options = {})
        case backend
        when :memory
          MobME::Infrastructure::RedisQueue::Memory.new(options)
        else :redis
          MobME::Infrastructure::RedisQueue::Redis.new(options)
        end
      end
    end
  end
end

require_relative 'redis_queue/exceptions'

require_relative 'redis_queue/backend'
require_relative 'redis_queue/backend/redis'
require_relative 'redis_queue/backend/memory'
