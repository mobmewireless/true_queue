
require 'ffi-rzmq'
require 'mobme/infrastructure/redis_queue/zeromq/connection_handler'
require 'redis/connection/synchrony'

module MobME::Infrastructure::RedisQueue::ZeroMQ
  class PersistenceServer
    def initialize(options = {})
      @queue = MobME::Infrastructure::RedisQueue.queue(:redis)
      @persistence_socket = options[:persistence_socket] || "ipc:///tmp/mobme-infrastructure-queue-persistence.sock"
      
      EM.synchrony do
        bind
        
        send_backlog_requests
      end
    end
    
    def bind
      @context = EM::ZeroMQ::Context.new(1)
      
      @persistence_request_server = @context.connect(ZMQ::REQ, @persistence_socket)
    end
    
    def send_backlog_requests
      loop do
        handler = MobME::Infrastructure::RedisQueue::ZeroMQ::ConnectionHandler.new(@persistence_request_server)
        handler.send_message Marshal.dump("BACKLOG")
        
        puts "Sent message"
        
        messages = handler.receive_message
        messages = Marshal.load(messages) rescue nil
        
        queue_return = case messages
        when nil
        when false
        else
          messages.each do |message|
            route_to_queue(message)
          end
        end
        
        EM::Synchrony.sleep(5)
      end
    end
    
    private
    def route_to_queue(message)
      method = method_from_message(message)
      args = arguments_from_message(message)
      
      puts "Processing: #{message.inspect}"
      
      begin
        @queue.send(method, *args)
      rescue NoMethodError
        false
      end
    end
    
    def method_from_message(message)
      message[0]
    end
    
    def arguments_from_message(message)
      message[1]
    end
  end
end
