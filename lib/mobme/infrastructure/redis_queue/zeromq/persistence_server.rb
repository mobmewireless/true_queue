
require 'ffi-rzmq'
require 'mobme/infrastructure/redis_queue/zeromq/connection_handler'
require 'redis/connection/synchrony'
require 'digest/sha1'

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
        puts "Sent BACKLOG"
        
        messages = handler.receive_message
        messages = Marshal.load(messages) rescue nil
        
        case messages
        when nil
        when false
        else
          unless messages.empty?
            messages.each do |message|
              route_to_queue(message)
            end
      
            backlog_signature = message_backlog_signature(messages)
            handler.send_message Marshal.dump("ACK #{backlog_signature}")
            puts "Sent ACK #{backlog_signature}"
      
            message = handler.receive_message
            message = Marshal.load(message) rescue nil
            puts "ACK OK"
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
    
    def message_backlog_signature(message_backlog)
      Digest::SHA1.hexdigest(Marshal.dump(message_backlog))
    end
  end
end
