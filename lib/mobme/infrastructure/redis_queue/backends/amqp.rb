
require "bunny"

class MobME::Infrastructure::RedisQueue::Backends::AMQP < MobME::Infrastructure::RedisQueue::Backend
  def initialize(options = {})
    @bunny_options = options[:bunny_options] || {}
    @amqp_queues = {}
    
    configure
  end
  
  def add(queue, item, metadata = {})
    metadata = normalize_metadata(metadata)
    
    #register the queue if needed
    queue_for(queue)
    
    @amqp_exchange.publish(serialize_item(item, metadata), :key => queue)
  end
  
  # Adds many items together
  def add_bulk(queue, items = [])
    items.each do |item|
      add(queue, item, {})
    end
  end
  
  def remove(queue)
    item = queue_for(queue).pop[:payload]
    (:queue_empty == item) ? nil : unserialize_item(item)
  end
  
  def peek(queue)
    raise NotImplementedError, "AMQP doesn't support peek!"
  end
  
  def size(queue)
    queue_for(queue).message_count
  end
  
  def list(queue)
    raise NotImplementedError, "AMQP doesn't support list!"
  end
  
  def empty(queue)
    queue_for(queue).purge
  end
  
  def list_queues
    @amqp_queues.keys
  end
  
  def remove_queues(*queues)
    queues = list_queues if queues.empty?
    queues.each do |queue|
      queue_for(queue).delete
      @amqp_queues.delete(queue)
    end
  end
  alias :remove_queue :remove_queues
  
  private
  def queue_for(queue)
    if @amqp_queues[queue]
      @amqp_queues[queue]
    else
      @amqp_queues[queue] = @amqp_client.queue(queue)
    end
  end
  
  def configure
    exchange = @bunny_options.delete(:exchange) || ''
    @amqp_client ||= Bunny.new(@bunny_options)
    
    connect
    @amqp_exchange ||= @amqp_client.exchange(exchange)
  end
  
  def connect
    if :not_connected == @amqp_client.status
      @amqp_client.start
    end
  end
end
