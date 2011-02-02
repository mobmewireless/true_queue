
require '../redis-queue'

queue = RedisQueue.new

queue.add("set", "token")

puts queue.add("hello", "world")
puts queue.add("orange", "kongre")

puts queue.size("hello")
puts queue.size("orange")

puts queue.remove("set")
puts queue.remove("hello")
puts queue.remove("hello")
puts queue.remove("orange")

puts queue.size("hello")
puts queue.size("orange")

puts queue.list_queues
