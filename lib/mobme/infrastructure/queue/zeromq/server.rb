
require 'ffi-rzmq'
require 'digest/sha1'

require 'mobme/infrastructure/queue'
require 'mobme/infrastructure/queue/zeromq/connection_handler'

require 'em-synchrony'
require 'em-zeromq'

module MobME::Infrastructure::Queue::ZeroMQ
  class Server
    def initialize(options = {})
      @queue = MobME::Infrastructure::Queue.queue(:memory)
      @messages_socket = options[:messages_socket] || "ipc:///tmp/mobme-infrastructure-queue-messages.sock"
      @persistence_socket = options[:persistence_socket] || "ipc:///tmp/mobme-infrastructure-queue-persistence.sock"
      
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
        handler = MobME::Infrastructure::Queue::ZeroMQ::ConnectionHandler.new(@messages_reply_server)
        message = @messages_reply_server.handler.receive_message
        
        message = Marshal.load(message) rescue nil
        
        queue_return = if message
          route_to_queue(message)
        end
        
        @messages_reply_server.handler.send_message(Marshal.dump(queue_return))
      end
    end
    
    def listen_to_backlog_requests
      loop do
        handler = MobME::Infrastructure::Queue::ZeroMQ::ConnectionHandler.new(@persistence_reply_server)
        message = @persistence_reply_server.handler.receive_message
        
        
        message = Marshal.load(message) rescue nil
      
        queue_return = if message == "BACKLOG"
          queues_snapshot
        elsif ack_message?(message)
          puts "Got ACK: #{signature_from_ack_message(message)}"
          true
        else
          false
        end
        
        @persistence_reply_server.handler.send_message(Marshal.dump(queue_return))
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
    
    def queues_snapshot
      snapshot = {}
      queues = @queue.list_queues
      queues.each do |queue|
        snapshot[queue] = @queue.list queue
      end
      
      snapshot
    end
    
    def method_from_message(message)
      message[0]
    end
    
    def arguments_from_message(message)
      message[1]
    end
    
    def ack_message?(message)
      message.match(/^ACK (.*)/)
    end
    
    def signature_from_ack_message(message)
      message.match(/^ACK (.*)/).to_a[1]
    end
  end
end
