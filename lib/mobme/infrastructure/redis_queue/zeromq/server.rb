
require 'ffi-rzmq'
require 'mobme/infrastructure/redis_queue/zeromq/connection_handler'

module MobME::Infrastructure::RedisQueue::ZeroMQ
  class Server
    def initialize(options = {})
      @queue = MobME::Infrastructure::RedisQueue.queue(:memory)
      @messages_socket = options[:messages_socket] || "ipc:///tmp/mobme-infrastructure-queue-messages.sock"
      @persistence_socket = options[:persistence_socket] || "ipc:///tmp/mobme-infrastructure-queue-persistence.sock"
      @message_backlog = []
      
      EM.synchrony do
        bind
        
        Fiber.new { listen_to_messages }.resume
        Fiber.new { listen_to_backlog_requests }.resume
      end
    end
    
    def bind
      @context = EM::ZeroMQ::Context.new(1)
      
      @messages_reply_server = @context.bind(ZMQ::REP, @messages_socket)
      @persistence_reply_server = @context.bind(ZMQ::REP, @persistence_socket)
    end
    
    def listen_to_messages
      loop do
        handler = MobME::Infrastructure::RedisQueue::ZeroMQ::ConnectionHandler.new(@messages_reply_server)
        message = @messages_reply_server.handler.receive_message
        
        message = Marshal.load(message) rescue nil
        
        queue_return = if message
          store_message_backlog(message)
          route_to_queue(message)
        end
        
        @messages_reply_server.handler.send_message(Marshal.dump(queue_return))
      end
    end
    
    def listen_to_backlog_requests
      loop do
        handler = MobME::Infrastructure::RedisQueue::ZeroMQ::ConnectionHandler.new(@persistence_reply_server)
        message = @persistence_reply_server.handler.receive_message
        
        
        message = Marshal.load(message) rescue nil
      
        queue_return = if message == "BACKLOG"
          @message_backlog
        else
          false
        end
      
        @persistence_reply_server.handler.send_message(Marshal.dump(queue_return))
        @message_backlog = []
      end
    end
    
    private
    def route_to_queue(message)
      method = method_from_message(message)
      args = arguments_from_message(message)
      
      begin
        @queue.send(method, *args)
      rescue NoMethodError
        false
      end
    end
    
    def store_message_backlog(message)
      @message_backlog << message
    end
    
    def method_from_message(message)
      message[0]
    end
    
    def arguments_from_message(message)
      message[1]
    end
  end
end
