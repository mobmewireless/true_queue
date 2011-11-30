
require 'em-zeromq'
require 'em-synchrony'
require 'mobme/infrastructure/redis_queue/zeromq/connection_handler'

class MobME::Infrastructure::RedisQueue::Backends::ZeroMQ < MobME::Infrastructure::RedisQueue::Backend
  def initialize(options = {})
    @socket = options[:socket] || "ipc:///tmp/redis-queue.sock"
    connect
  end
  
  def connect
    @context = EM::ZeroMQ::Context.new(1)
    @pool = EM::Synchrony::ConnectionPool.new(:size => 20) do
      @context.connect(ZMQ::REQ, @socket)
    end
  end
  
  def add(queue, item, metadata = {})
    dispatch(:add, queue, item, metadata)
  end
  
  # Adds many items together
  def add_bulk(queue, items = [])
    dispatch(:add_bulk, queue, items)
  end
  
  # Simple remove without reserving items
  def remove(queue)
    dispatch(:remove, queue)
  end
  
  def peek(queue)
    dispatch(:peek, queue)
  end
  
  def size(queue)
    dispatch(:size, queue)
  end
  
  def list(queue)
    dispatch(:list, queue)
  end
  
  def empty(queue)
    dispatch(:empty, queue)
  end
  
  def list_queues
    dispatch(:list_queues)
  end
  
  def remove_queues(*queues)
    dispatch(:remove_queues, *queues)
  end
  alias :remove_queue :remove_queues
  
  private
  def dispatch(method, *args)
    @pool.execute(false) do |connection|
      handler = MobME::Infrastructure::RedisQueue::ZeroMQ::ConnectionHandler.new(connection)
    
      message = Marshal.dump([method, args])
    
      handler.send_message(message)
      
      Marshal.load(handler.receive_message)
    end
  end
end
