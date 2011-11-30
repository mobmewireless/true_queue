
require 'ffi-rzmq'
require 'mobme/infrastructure/redis_queue/zeromq/connection_handler'

module MobME::Infrastructure::RedisQueue::ZeroMQ
  class Server
    def initialize(options = {})
      @queue = MobME::Infrastructure::RedisQueue.queue(options[:backend] || :memory)
      @socket = options[:socket] || "ipc:///tmp/redis-queue.sock"
      
      EM.synchrony do
        bind
        listen_to_messages
      end
    end
    
    def bind
      @context = EM::ZeroMQ::Context.new(1)
      @server = @context.bind(ZMQ::REP, @socket)
    end
    
    def listen_to_messages
      loop do
        handler = MobME::Infrastructure::RedisQueue::ZeroMQ::ConnectionHandler.new(@server)
        message = handler.receive_message
        
        message = Marshal.load(message) rescue nil
        
        queue_return = if message
          route_to_queue(message)
        end
        
        handler.send_message(Marshal.dump(queue_return))
      end
    end
    
    private
    def route_to_queue(message)
      method = method_from_message(message)
      args = message[1]
      @queue.send(method, *args)
    end
    
    def method_from_message(message)
      message[0]
    end
  end
end
