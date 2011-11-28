
require 'em-zeromq'
require 'em-synchrony'

class EM::Protocols::ZMQConnectionHandler
  attr_reader :received

  def initialize(connection)
    @connection = connection
    @client_fiber = Fiber.current
    @connection.setsockopt(ZMQ::IDENTITY, "req-#{@client_fiber.object_id}")
    @connection.handler = self
  end
  
  def recv_msg
    @connection.register_readable
    messages = Fiber.yield
    messages.map(&:copy_out_string)
  end

  def send_msg(*parts)
    puts "Sending"
    queued = @connection.send_msg(*parts)
    @connection.register_readable
    puts "Yielding"
    messages = Fiber.yield
    messages.map(&:copy_out_string)
  end

  def on_readable(socket, messages)
    puts "Readable"
    @client_fiber.resume(messages)
  end
end

class MobME::Infrastructure::RedisQueue::Backends::ZeroMQ < MobME::Infrastructure::RedisQueue::Backend
  def initialize(options)
    @socket = options[:socket] || "tcp://127.0.0.1:6091"
    connect
  end
  
  def connect
    context = EM::ZeroMQ::Context.new(1)
    @pool = EM::Synchrony::ConnectionPool.new(:size => 20) do
      context.connect(ZMQ::REQ, @socket)
    end
  end
  
  def add(queue, item, metadata = {})
    puts "Adding"
    @pool.execute(false) do |conn|
      handler = EM::Protocols::ZMQConnectionHandler.new(conn)
      resp = handler.send_msg("HELLO").first
      [200, {}, resp]
    end
  end
end
