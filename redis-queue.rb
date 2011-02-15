
require 'redis'
require 'json'

# RedisQueue is a simple queueing system built on Redis
# Adapted from: https://gist.github.com/616837 and restmq.com
class RedisQueue

  # The namespace that all redis queue keys live inside Redis
  NAMESPACE = 'redis:queue:'

  # The set used to store all keys
  QUEUESET = 'redis:queue:set'

  # The UUID suffix for keys that store values
  UUID_SUFFIX = ':uuid'

  # The sorted set suffix for the list of all keys in a queue
  QUEUE_SUFFIX = ':queue'

  # Initialises the RedisQueue
  #   options is a hash of all options to pass to the queue
  #   options[:redis_options] is passed on to the underlying Redis client
  #     and can take any Redis connect options hash.
  def initialize(options = {})
    redis_options = options.delete(:redis_options) || {}

    # Connect to Redis!
    connect(redis_options)
  end

  # Connect to Redis
  # :options: is an option hash to pass to the Redis client as is
  def connect(options)
    @redis = Redis.new(options)
  end

  # List all queues in the RedisQueue
  def list_queues
    @redis.smembers QUEUESET
  end

  # Add a value to a queue
  #   :queue: is the queue name
  #   :item: is the item to add
  #   :metadata: is stored with the item and returned.
  #   :metadata['dequeue-timestamp'] => Time is treated specially.
  #     An item with a dequeue-timestamp is only dequeued after this timestamp.
  #   :metadata['priority'] => Integer is treated specially.
  #     An item with a higher priority is dequeued first.
  #
  #   Note: dequeue-timestamp overrides any set priority.
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
  # :queue: is the queue name
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
  # :queue: is the queue name
  def size(queue_name)
    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX
    length = (@redis.zcard queue)
  end
end
