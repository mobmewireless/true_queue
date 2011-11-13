
require 'redis'
require 'json'

module MobME
  module Infrastructure
  end
end

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
  def add(queue_name, item, metadata = {})
    raise ArgumentError, "Metadata must be a hash, but #{metadata.class} given" unless metadata.is_a? Hash

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

    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX

    uuid = @redis.incr NAMESPACE + queue_name.to_s + UUID_SUFFIX
    @redis.sadd QUEUESET, queue
    lkey = NAMESPACE + queue_name + ':' + uuid.to_s
    @redis.set lkey, JSON::dump([item, metadata])

    # zadd adds to a sorted set, which is sorted by score.
    # When set, the dequeue_timestamp is used as the score. If not, it's just the current timestamp.
    # When set, current timestamp is divided by the integer priority.
    score = (dequeue_timestamp && dequeue_timestamp.to_i) || (Time.now.to_i / (priority || 1))
    @redis.zadd queue, score, lkey

    lkey
  end

  # Remove an item from a queue
  # @param [String] queue_name is the queue name
  def remove(queue_name)
    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX

    # Remove the first item!
    key = (@redis.zrangebyscore queue, "-inf", Time.now.to_i, {:limit => [0, 1]}).first
    if key
      @redis.zrem queue, key

      value = @redis.get key
      @redis.del key
      json_value = value || JSON::dump(value) #handle nil to null

      JSON::load(json_value)
    else
      nil
    end
  end

  # Find the size of a queue
  # @param [String] queue_name is the queue name
  def size(queue_name)
    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX
    length = (@redis.zcard queue)
  end

  # Clear the queue
  # @param [String] queue_name is the queue name to clear
  def clear(queue_name)
    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX
    batch_size = 1_000 # keep this low as the time complexity of zrangebyscore is O(log(N)+M) : M -> the size
    count = 0
    (size(queue_name)/batch_size + 1).times do |i|
      limit = [0 + (batch_size * i) , batch_size * (i + 1)]
      keys = (@redis.zrangebyscore queue, "-inf", Time.now.to_i, {:limit => limit})
      count += @redis.del keys.map { "%6s" }.join, *keys
    end
    @redis.del queue # a deleted queue is = empty queue ( the queue is still present in redis:queue:set)
    count
  end
  
  # List all queues
  def list_queues
    list = @redis.smembers QUEUESET
    name_list = []
    list.map do |name|
      if m = name.match(/^redis:queue:(.*):queue$/)
        name_list << m.captures[0]
      end
    end
    name_list
  end
end
