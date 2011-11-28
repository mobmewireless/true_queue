
class MobME::Infrastructure::RedisQueue::Backends::Redis < MobME::Infrastructure::RedisQueue::Backend

  # The namespace that all redis queue keys live inside Redis
  NAMESPACE = 'redis:queue:'

  # The set used to store all keys
  QUEUESET = 'redis:queue:set'

  # The UUID suffix for keys that store values
  UUID_SUFFIX = ':uuid'

  # The sorted set suffix for the list of all keys in a queue
  QUEUE_SUFFIX = ':queue'
  
  # The hash suffix for the hash that stores values of a queue
  VALUE_SUFFIX = ':values'

  # Initialises the RedisQueue
  # @param [Hash] options all options to pass to the queue
  # @option options [Hash] :redis_options is passed on to the underlying Redis client
  def initialize(options = {})
    redis_options = options.delete(:redis_options) || {}

    # Connect to Redis!
    connect(redis_options)
  end

  # Connect to Redis
  # @param [Hash] options to pass to the Redis client as is
  # @option options :connection Instead of making a new connection, the queue will reuse this existing Redis connection
  def connect(options)
    @redis = options.delete(:connection)
    @redis ||= Redis.new(options)
  end

  # Add a value to a queue
  # @param [String] queue_name The queue name to add to. 
  # @param [Object] item is the item to add
  # @param [Hash] metadata is stored with the item and returned.
  # @option metadata [Time] dequeue-timestamp An item with a dequeue-timestamp is only dequeued after this timestamp.
  # @option metadata [Integer] priority An item with a higher priority is dequeued first. Always between 1 and 100.
  # @return [String] A unique key in the queue name where the item is set.
  def add(queue, item, metadata = {})
    raise ArgumentError, "Metadata must be a hash, but #{metadata.class} given" unless metadata.is_a? Hash

    dequeue_timestamp, priority = extract_options_from_metadata(metadata)
    uuid = generate_uuid(queue)
    
    add_to_queueset(queue)
    add_to_queue(queue, uuid, dequeue_timestamp, priority)
    write_value(queue, uuid, item, metadata)
    
    uuid
  end

  # Remove an item from a queue.
  # When a block is passed, the item is reserved instead and automatically put back in case of an error.
  # Raise MobME::Infrastructure::RedisQueueRemoveAbort within the block to manually abort the remove.
  #
  # @param [String] queue_name is the queue name
  # @yield [[Object, Hash]] An optional block that is passed the item being remove alongside metadata.
  # @return [[Object, Hash]] The item plus the metadata in the queue
  def remove(queue, &block)
    begin
      # Remove the first item!
      uuid = first_in_queue(queue)
      if uuid
        # If we're not able to remove the key from the set here, it means that
        # some other thread (or evented operation) has done it before us, so
        # the current remove is invalid and we should retry!
        raise MobME::Infrastructure::RedisQueue::RemoveConflictException unless remove_from_queue(queue, uuid)
      
        queue_item = read_value(queue, uuid)
        
        # When a block is given, safely reserve the queue item
        if block_given?
          begin
            block.call(queue_item)
            remove_value(queue, uuid)
          rescue #generic error
            put_back_in_queue(queue, uuid, queue_item)
            
            # And now re-raise the error
            raise
          rescue MobME::Infrastructure::RedisQueue::RemoveAbort
            put_back_in_queue(queue, uuid, queue_item)
          end
        else
          remove_value(queue, uuid)
          queue_item
        end
      else
        nil
      end
    rescue MobME::Infrastructure::RedisQueue::RemoveConflictException
      retry
    end
  end
  
  # Peek into the first item in a queue without removing it
  # @param [String] queue_name is the queue name
  # @return [[Object, Hash]] The item plus the metadata in the queue
  def peek(queue)
    uuid = first_in_queue(queue)
    read_value(queue, uuid)
  end

  # Find the size of a queue
  # @param [String] queue_name is the queue name
  # @return [Integer] The size of the queue
  def size(queue)
    queue = NAMESPACE + queue.to_s + QUEUE_SUFFIX
    length = (@redis.zcard queue)
  end
  
  # Lists all items in the queue. This is an expensive operation
  # @param [String] queue_name is the queue name
  # @return [Array<Object, Hash>] An array of list items, the first element the object stored and the second, metadata
  def list(queue)
    batch_size = 1_000 # keep this low as the time complexity of zrangebyscore is O(log(N)+M) : M -> the size
    
    count = 0; values = []
    (size(queue)/batch_size + 1).times do |i|
      limit = [(batch_size * i), batch_size]
      uuids = range_in_queue(queue, limit)
      batch_values = uuids.map { |uuid| read_value(queue, uuid) }
      values.push(*batch_values)
    end
    
    values
  end

  # Clear the queue
  # @param [String] queue_name is the queue name to clear
  def empty(queue)
    # Delete key and value stores.
    @redis.del "#{NAMESPACE}#{queue}#{VALUE_SUFFIX}"
    @redis.del "#{NAMESPACE}#{queue}#{QUEUE_SUFFIX}"
  end
  
  # List all queues
  # @return [Array] A list of queues (includes empty queues that were once available)
  def list_queues
    @redis.smembers QUEUESET
  end
  
  # Delete queues
  # @param [optional String ...] queues A list of queues to delete. If empty, all queues are deleted.
  def remove_queues(*queues)
    queues = list_queues if queues.empty?
    queues.each do |queue_name|
      empty(queue_name)
      remove_from_queueset(queue_name)
    end
  end
  alias :remove_queue :remove_queues
  
  private
  def add_to_queueset(queue)
    @redis.sadd QUEUESET, queue
  end
  
  def remove_from_queueset(queue)
    @redis.srem QUEUESET, queue
  end
  
  def first_in_queue(queue)
    queue = NAMESPACE + queue.to_s + QUEUE_SUFFIX
    (@redis.zrangebyscore queue, "-inf", (Time.now.to_f * 1000000).to_i, {:limit => [0, 1]}).first
  end
  
  def range_in_queue(queue, limit)
    queue = NAMESPACE + queue.to_s + QUEUE_SUFFIX
    (@redis.zrangebyscore queue, "-inf", (Time.now.to_f * 1000000).to_i, {:limit => limit})
  end
  
  def add_to_queue(queue, uuid, dequeue_timestamp, priority)
    # zadd adds to a sorted set, which is sorted by score.
    # When set, the dequeue_timestamp is used as the score. If not, it's just the current timestamp.
    # When set, current timestamp is divided by the integer priority.    
    queue = NAMESPACE + queue.to_s + QUEUE_SUFFIX 
    @redis.zadd queue, score_from_metadata(dequeue_timestamp, priority), uuid
  end
  
  def remove_from_queue(queue, uuid)
    queue = NAMESPACE + queue.to_s + QUEUE_SUFFIX
    (@redis.zrem queue, uuid)
  end
  
  def put_back_in_queue(queue, uuid, queue_item)
    # Put the item back in the queue
    metadata = queue_item[1]
    dequeue_timestamp, priority = extract_options_from_metadata(metadata)
    add_to_queue(queue, uuid, dequeue_timestamp, priority)
  end
  
  def write_value(queue, uuid, item, metadata)
    value_hash = "#{NAMESPACE}#{queue}#{VALUE_SUFFIX}"
    
    @redis.hset value_hash, uuid, serialize_item(item, metadata)
  end
  
  def read_value(queue, uuid)
    if uuid
      value_hash = "#{NAMESPACE}#{queue}#{VALUE_SUFFIX}"
      
      value = @redis.hget value_hash, uuid
      unserialize_item(value)
    else
      nil
    end
  end
  
  def remove_value(queue, uuid)
    value_hash = "#{NAMESPACE}#{queue}#{VALUE_SUFFIX}"
    
    @redis.hdel value_hash, uuid
  end
  
  def generate_uuid(queue)
    @redis.incr NAMESPACE + queue.to_s + UUID_SUFFIX
  end
end
