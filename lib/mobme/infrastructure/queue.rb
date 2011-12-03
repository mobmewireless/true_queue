
require 'redis'
require 'yajl'

module MobME
  module Infrastructure
    module Queue
      def self.queue(backend, options = {})
        case backend
        when :memory
          MobME::Infrastructure::Queue::Backends::Memory.new(options)
        when :redis
          MobME::Infrastructure::Queue::Backends::Redis.new(options)
        when :zeromq             
          MobME::Infrastructure::Queue::Backends::ZeroMQ.new(options)
        when :amqp               
          MobME::Infrastructure::Queue::Backends::AMQP.new(options)
        end
      end
    end
  end
end

require_relative 'queue/exceptions'
                  
require_relative 'queue/backend'
require_relative 'queue/backends/redis'
require_relative 'queue/backends/memory'
require_relative 'queue/backends/zeromq'
require_relative 'queue/backends/amqp'
