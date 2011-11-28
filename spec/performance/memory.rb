

# time bundle exec ruby spec/performance/memory.rb  
#
# Perf data:
# bundle exec ruby spec/performance/memory.rb  4.98s user 0.42s system 99% cpu 5.436 total

$:.push(File.expand_path(File.dirname(__FILE__) + "/../../lib"))

require_relative "../spec_helper"

queue = MobME::Infrastructure::RedisQueue::Memory.new

count = ARGV[0] || 100_000

count.times do |i|
  queue.add("perf", "token-9876")
end

puts "Add done"

count.times do |i|
  val = queue.remove("perf")
end

puts "Remove done"