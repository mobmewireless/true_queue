

# ruby -rubygems performance.rb  23.77s user 11.10s system 59% cpu 58.499 total

require '../redis-queue'

queue = RedisQueue.new

count = ARGV[0] || 100_000

count.times do |i|
  queue.add("perf", "token#{i}")
end

count.times do |i|
  queue.remove("perf")
end

