

# time bundle exec ruby spec/performance/redis.rb  
#
# Perf data:
# bundle exec ruby spec/performance/redis.rb  31.85s user 14.27s system 50% cpu 1:30.92 total
# [98530] 28 Nov 11:45:13 - 1 clients connected (0 slaves), 21969856 bytes in use

$:.push(File.expand_path(File.dirname(__FILE__) + "/../../lib"))

require_relative "../spec_helper"

queue = MobME::Infrastructure::RedisQueue::Redis.new

count = ARGV[0] || 100_000

count.times do |i|
  queue.add("perf", "token-9876")
end

puts "Add done"

count.times do |i|
  val = queue.remove("perf")
end

puts "Remove done"