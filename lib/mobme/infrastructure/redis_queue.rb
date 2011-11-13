
require 'redis'
require 'yajl'

module MobME
  module Infrastructure
  end
end

class MobME::Infrastructure::RedisQueueRemoveConflictException < Exception; end

# Raise this to abort a remove and put back the item
class MobME::Infrastructure::RedisQueueRemoveAbort < Exception; end

# RedisQueue is a simple queueing system built on Redis
# & adapted from RestMQ[http://restmq.com] and this gist[https://gist.github.com/616837]
class MobME::Infrastructure::RedisQueue

  # The namespace that all redis queue keys live inside Redis
  NAMESPACE = 'redis:queue:'

  # The set used to store all keys
  QUEUESET = 'redis:queue:set'

  # The UUID suffix for keys that store values
  UUID_SUFFIX = ':uuid'

  # The sorted set suffix for the list of all keys in a queue
  QUEUE_SUFFIX = ':queue'

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
  def add(queue_name, item, metadata = {})
    raise ArgumentError, "Metadata must be a hash, but #{metadata.class} given" unless metadata.is_a? Hash

    dequeue_timestamp, priority = extract_options_from_metadata(metadata)

    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX

    uuid = @redis.incr NAMESPACE + queue_name.to_s + UUID_SUFFIX
    @redis.sadd QUEUESET, queue
    lkey = NAMESPACE + queue_name + ':' + uuid.to_s
    @redis.set lkey, Yajl.dump([item, metadata])

    add_to_queueset(queue, lkey, dequeue_timestamp, priority)
    lkey
  end

  # Remove an item from a queue.
  # When a block is passed, the item is reserved instead and automatically put back in case of an error.
  # Raise MobME::Infrastructure::RedisQueueRemoveAbort within the block to manually abort the remove.
  #
  # @param [String] queue_name is the queue name
  # @yield [[Object, Hash]] An optional block that is passed the item being remove alongside metadata.
  # @return [[Object, Hash]] The item plus the metadata in the queue
  def remove(queue_name, &block)
    begin
      queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX

      # Remove the first item!
      lkey = (@redis.zrangebyscore queue, "-inf", Time.now.to_i, {:limit => [0, 1]}).first
      if lkey
        # If we're not able to remove the key from the set here, it means that
        # some other thread (or evented operation) has done it before us, so
        # the current remove is invalid and we should retry!
        raise MobME::Infrastructure::RedisQueueRemoveConflictException unless (@redis.zrem queue, lkey)
      
        queue_item = value_from_lkey(lkey)
        
        # When a block is given, safely reserve the queue item
        if block_given?
          begin
            block.call(queue_item)
            @redis.del lkey
          rescue #generic error
            put_back(queue, lkey, queue_item)
            
            # And now re-raise the error
            raise
          rescue MobME::Infrastructure::RedisQueueRemoveAbort
            put_back(queue, lkey, queue_item)
          end
        else
          @redis.del lkey
          queue_item
        end
      else
        nil
      end
    rescue MobME::Infrastructure::RedisQueueRemoveConflictException
      retry
    end
  end
  
  # Peek into the first item in a queue without removing it
  # @param [String] queue_name is the queue name
  # @return [[Object, Hash]] The item plus the metadata in the queue
  def peek(queue_name)
    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX

    # Find the first item!
    lkey = (@redis.zrangebyscore queue, "-inf", Time.now.to_i, {:limit => [0, 1]}).first
    
    value_from_lkey(lkey)
  end

  # Find the size of a queue
  # @param [String] queue_name is the queue name
  # @return [Integer] The size of the queue
  def size(queue_name)
    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX
    length = (@redis.zcard queue)
  end
  
  # Lists all items in the queue. This is an expensive operation
  # @param [String] queue_name is the queue name
  # @return [Array<Object, Hash>] An array of list items, the first element the object stored and the second, metadata
  def list(queue_name)
    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX
    batch_size = 1_000 # keep this low as the time complexity of zrangebyscore is O(log(N)+M) : M -> the size
    
    count = 0; values = []
    (size(queue_name)/batch_size + 1).times do |i|
      limit = [(batch_size * i), batch_size]
      lkeys = (@redis.zrangebyscore queue, "-inf", Time.now.to_i, {:limit => limit})
      batch_values = lkeys.map { |lkey| value_from_lkey(lkey) }
      values.push(*batch_values)
    end
    
    values
  end

  # Clear the queue
  # @param [String] queue_name is the queue name to clear
  # @return [Integer] The count of items cleared.
  def empty(queue_name)
    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX
    batch_size = 1_000 # keep this low as the time complexity of zrangebyscore is O(log(N)+M) : M -> the size
    count = 0
    (size(queue_name)/batch_size + 1).times do |i|
      limit = [(batch_size * i), batch_size]
      keys = (@redis.zrangebyscore queue, "-inf", Time.now.to_i, {:limit => limit})
      count += @redis.del keys.map { "%6s" }.join, *keys
    end
    @redis.del queue # a deleted queue is = empty queue ( the queue is still present in the QUEUESET)
    count
  end
  
  # List all queues
  # @return [Array] A list of queues (includes empty queues that were once available)
  def list_queues
    list = @redis.smembers QUEUESET
    name_list = []
    list.map do |name|
      if m = name.match(/^#{NAMESPACE}(.*)#{QUEUE_SUFFIX}$/)
        name_list << m.captures[0]
      end
    end
    name_list
  end
  
  # Delete queues
  # @param [optional String ...] queues A list of queues to delete. If empty, all queues are deleted.
  def remove_queues(*queues)
    queues = list_queues if queues.empty?
    queues.each do |queue_name|
      empty(queue_name)
      @redis.srem QUEUESET, "#{NAMESPACE}#{queue_name}#{QUEUE_SUFFIX}"
    end
  end
  alias :remove_queue :remove_queues
  
  private
  def add_to_queueset(queue, lkey, dequeue_timestamp, priority)
    # zadd adds to a sorted set, which is sorted by score.
    # When set, the dequeue_timestamp is used as the score. If not, it's just the current timestamp.
    # When set, current timestamp is divided by the integer priority.
    score = (dequeue_timestamp && dequeue_timestamp.to_i) || (Time.now.to_i / (priority || 1))
    @redis.zadd queue, score, lkey
  end
  
  def extract_options_from_metadata(metadata)
    if dequeue_timestamp = metadata['dequeue-timestamp']
      unless dequeue_timestamp.is_a? Time
        raise ArgumentError, "dequeue-timestamp must be an instance of Time, but #{dequeue_timestamp.class} given"
      end
    end

    if priority = metadata['priority']
      unless (priority.is_a? Integer) && priority.between?(1, 100)
        raise ArgumentError, "priority must be an Integer between 1 and 100, but #{priority.class} given"
      end
    end
    
    [dequeue_timestamp, priority]
  end
  
  def put_back(queue, lkey, queue_item)
    # Put the item back in the queue
    metadata = queue_item[1]
    dequeue_timestamp, priority = extract_options_from_metadata(metadata)
    add_to_queueset(queue, lkey, dequeue_timestamp, priority)
  end
  
  def value_from_lkey(lkey)
    if lkey
      value = @redis.get lkey
      json_value = value || Yajl.dump(value) #handle nil to null

      Yajl.load(json_value)
    else
      nil
    end
  end
end
