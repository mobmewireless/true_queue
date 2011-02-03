
require '../redis-queue'

queue = RedisQueue.new


#queue.add("orange", "scheduled at #{Time.now}", {'dequeue-timestamp' => Time.now + 5})
#queue.add("blue", "scheduled at #{Time.now}", {'dequeue-timestamp' => Time.now + 5})
puts queue.add("orange", "kongre")


p "Orange"
p queue.remove("orange")
p queue.remove("orange")
p queue.remove("orange")
p queue.remove("orange")
p
p "Blue"
p queue.remove("blue")
p queue.remove("blue")
p queue.remove("blue")
p queue.remove("blue")
p
p queue.size("orange")
p
p queue.list_queues
