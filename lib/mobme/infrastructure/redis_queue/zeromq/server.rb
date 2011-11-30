
require 'ffi-rzmq'
require 'mobme/infrastructure/redis_queue/zeromq/connection_handler'
require 'digest/sha1'

module MobME::Infrastructure::RedisQueue::ZeroMQ
  class Server
    def initialize(options = {})
      @queue = MobME::Infrastructure::RedisQueue.queue(:memory)
      @messages_socket = options[:messages_socket] || "ipc:///tmp/mobme-infrastructure-queue-messages.sock"
      @persistence_socket = options[:persistence_socket] || "ipc:///tmp/mobme-infrastructure-queue-persistence.sock"
      @message_backlog = []
      @message_backlogs_waiting_ack = {}
      
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
          if @message_backlog.empty?
            nil
          else
            add_message_backlog_to_waiting_ack(@message_backlog)
            @message_backlog.dup
          end
        elsif ack_message?(message)
          ack_siganture = signature_from_ack_message(message)
          
          puts "Got Ack Signature: #{ack_siganture}"
          remove_status = remove_message_backlog_from_waiting_ack(ack_siganture)
          puts "#{@message_backlogs_waiting_ack.length} waiting in backlog ack queue"
          true
        else
          false
        end
        
        @message_backlog = []
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
    
    def store_message_backlog(message)
      @message_backlog << message
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
    
    def add_message_backlog_to_waiting_ack(message_backlog)
      backlog_signature = message_backlog_signature(message_backlog)
      @message_backlogs_waiting_ack[backlog_signature] = message_backlog.dup
    end
    
    def remove_message_backlog_from_waiting_ack(backlog_signature)
      @message_backlogs_waiting_ack.delete(backlog_signature)
    end
    
    def message_backlog_signature(message_backlog)
      Digest::SHA1.hexdigest(Marshal.dump(message_backlog))
    end
  end
end
