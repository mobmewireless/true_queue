
require 'ffi-rzmq'

module MobME::Infrastructure::RedisQueue::ZeroMQ
  class Server
    def initialize(options = {})
      @queue = MobME::Infrastructure::RedisQueue.queue(options[:backend] || :memory)
      @socket = options[:socket] || "tcp://127.0.0.1:6091"
      
      EM.synchrony do
        bind
        route_to_queue
      end
    end
    
    def bind
      context = EM::ZeroMQ::Context.new(1)
      @server = context.bind(ZMQ::REP, @socket)
      puts "Connected."
    end
    
    def route_to_queue
      loop do
        puts "Listening..."
        handler = EM::Protocols::ZMQConnectionHandler.new(@server)
        message = handler.recv_msg
        
        puts "Sending"
        handler.send_msg("OK")
      end
    end
  end
end
