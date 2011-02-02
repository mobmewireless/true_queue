
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
    b = @redis.smembers QUEUESET
    Yajl.dump(b)
  end
  
  # Add a value to a queue
  # :queue: is the queue name
  # :item: is the item to add
  def add(queue, item)
    queue_name = NAMESPACE + queue.to_s + QUEUE_SUFFIX
    uuid = @redis.incr NAMESPACE + queue.to_s + UUID_SUFFIX 
    @redis.sadd QUEUESET, queue_name
    lkey = NAMESPACE + queue + ':' + uuid.to_s
    @redis.set lkey, Yajl.dump(item)
    @redis.lpush queue_name, lkey
    Yajl.dump(lkey)
  end
  
  # Remove an item from a queue
  # :queue: is the queue name
  def remove(queue)
    queue = NAMESPACE + queue.to_s + QUEUE_SUFFIX
    b = @redis.rpop queue
    v = @redis.get b
    v || Yajl.dump(v)
  end
  
  # Find the size of a queue
  # :queue: is the queue name
  def size(queue)
    queue = NAMESPACE + queue.to_s + QUEUE_SUFFIX
    length = @redis.llen queue
    Yajl.dump(length)
  end
end
