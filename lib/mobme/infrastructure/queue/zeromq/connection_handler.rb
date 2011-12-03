
module MobME::Infrastructure::Queue::ZeroMQ
  class ConnectionHandler
    attr_accessor :request

    def initialize(connection, identity = "")
      @connection = connection
      @connection.handler = self
      @connection.identity = "#{identity ? "#{identity}:" : ""}#{@client_fiber.object_id}"
      @connection.notify_readable = false
      @connection.notify_writable = false

      @send_messages_buffer = nil
    end

    def receive_message
      EM.next_tick { @connection.register_readable }

      @client_fiber = Fiber.current
      Fiber.yield 
    end

    def send_message(*messages)
      @send_messages_buffer = messages
      EM.next_tick { @connection.register_writable }

      @client_fiber = Fiber.current
      Fiber.yield 
    end

    def on_readable(connection, message)
      request = message.map(&:copy_out_string).join
      message.each { |part| part.close }

      @connection.notify_readable = false
      @connection.notify_writable = false

      @client_fiber.resume(request)
    end

    def on_writable(connection)    
      return_value = connection.send_msg *@send_messages_buffer

      @connection.notify_readable = false
      @connection.notify_writable = false

      @client_fiber.resume(return_value)
    end
  end
end