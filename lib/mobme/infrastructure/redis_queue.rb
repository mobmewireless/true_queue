
require 'redis'
require 'yajl'

module MobME
  module Infrastructure
    module RedisQueue
      def self.queue(backend, options = {})
        case backend
        when :memory
          MobME::Infrastructure::RedisQueue::Backends::Memory.new(options)
        when :redis
          MobME::Infrastructure::RedisQueue::Backends::Redis.new(options)
        when :zeromq
          MobME::Infrastructure::RedisQueue::Backends::ZeroMQ.new(options)
        end
      end
    end
  end
end

require_relative 'redis_queue/exceptions'

require_relative 'redis_queue/backend'
require_relative 'redis_queue/backends/redis'
require_relative 'redis_queue/backends/memory'
require_relative 'redis_queue/backends/zeromq'

