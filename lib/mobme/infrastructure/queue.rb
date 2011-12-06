require 'yajl'

module MobME
  module Infrastructure
    module Queue
    end
  end
end

require_relative 'queue/backend'
require_relative 'queue/exceptions'

module MobME
  module Infrastructure
    module Queue
      def self.queue(backend, options = {})
        case backend
        when :memory
          require_relative 'queue/backends/memory'
          MobME::Infrastructure::Queue::Backends::Memory.new(options)
        when :redis
          require_relative 'queue/backends/redis'
          MobME::Infrastructure::Queue::Backends::Redis.new(options)
        when :zeromq             
          require_relative 'queue/backends/zeromq'
          MobME::Infrastructure::Queue::Backends::ZeroMQ.new(options)
        when :amqp               
          require_relative 'queue/backends/amqp'
          MobME::Infrastructure::Queue::Backends::AMQP.new(options)
        end
      end
    end
  end
end

                  

