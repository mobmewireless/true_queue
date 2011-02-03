
require '../redis-queue'

queue = RedisQueue.new


#queue.add("orange", "scheduled at #{Time.now}", {'dequeue-timestamp' => Time.now + 5})
#queue.add("blue", "scheduled at #{Time.now}", {'dequeue-timestamp' => Time.now + 30})
#queue.add("orange", "kongre")
#queue.add("orange", "gun", {'priority' => 2})
#queue.add("orange", "rocket", {'priority' => 100, 'dequeue-timestamp' => Time.now + 5 })


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
