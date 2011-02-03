
require 'redis'
require 'yajl'

# RedisQueue is a simple queueing system built on Redis
# Adapted from: https://gist.github.com/616837 and restmq.com 
class RedisQueue
  
  # The namespace that all redis queue keys live inside Redis
  NAMESPACE = 'redis:queue:'
  
  # The set used to store all keys
  QUEUESET = 'redis:queue:set'
  
  # The UUID suffix for keys that store values
  UUID_SUFFIX = ':uuid'
  
  # The queue suffix for the list of all keys in a queue
  QUEUE_SUFFIX = ':queue'
  
  # The scheduled sorted set suffix for the list of scheduled keys in a queue
  SCHEDULED_SORTED_SET_SUFFIX = ':scheduled'
  
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
  def add(queue_name, item, metadata = {})
    raise ArgumentError, "Metadata must be a hash, but #{metadata.class} given" unless metadata.is_a? Hash
    
    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX
    scheduled_sorted_set = NAMESPACE + queue_name.to_s + SCHEDULED_SORTED_SET_SUFFIX
    
    uuid = @redis.incr NAMESPACE + queue_name.to_s + UUID_SUFFIX 
    @redis.sadd QUEUESET, queue
    lkey = NAMESPACE + queue_name + ':' + uuid.to_s
    @redis.set lkey, Yajl.dump([item, metadata])
    
    if metadata['dequeue-timestamp']
      @redis.zadd scheduled_sorted_set, metadata['dequeue-timestamp'].to_i, lkey
    else
      @redis.lpush queue, lkey
    end
    
    lkey
  end
  
  # Remove an item from a queue
  # :queue: is the queue name
  def remove(queue_name)
    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX
    scheduled_sorted_set = NAMESPACE + queue_name.to_s + SCHEDULED_SORTED_SET_SUFFIX
    
    # First check for any scheduled dequeues
    key = (@redis.zrangebyscore scheduled_sorted_set, '-INF', Time.now.to_i, { :limit => [0, 1] }).first
    if key
      @redis.zrem scheduled_sorted_set, key
    end
    
    # Fallback to the normal queue  
    key = @redis.rpop queue unless key
    
    value = @redis.get key
    @redis.del key
    json_value = value || Yajl.dump(value) #handle nil to null
    
    Yajl.load(json_value)
  end
  
  # Find the size of a queue
  # :queue: is the queue name
  def size(queue_name)
    queue = NAMESPACE + queue_name.to_s + QUEUE_SUFFIX
    scheduled_sorted_set = NAMESPACE + queue_name.to_s + SCHEDULED_SORTED_SET_SUFFIX
    
    length = (@redis.llen queue) + (@redis.zcount scheduled_sorted_set, '-inf', '+inf')
    length
  end
end
