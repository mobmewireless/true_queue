

# time bundle exec ruby spec/performance/redis.rb  
#
# Perf data (bulk adds):
# bundle exec ruby spec/performance/redis.rb  10.88s user 3.63s system 73% cpu 19.636 total
#
# Perf data:
# bundle exec ruby spec/performance/redis.rb  27.77s user 10.68s system 56% cpu 1:08.05 total
# [98530] 28 Nov 11:45:13 - 1 clients connected (0 slaves), 21969856 bytes in use

$:.push(File.expand_path(File.dirname(__FILE__) + "/../../lib"))

require_relative "../spec_helper"

queue = MobME::Infrastructure::Queue.queue(:redis)

count = ARGV[0] || 100_000

# count.times do |i|
#   queue.add("perf", "token-9876")
# end

# add_bulk!
100.times do |i|
  data = []
  (count/100).times do |i|
    data << "token-9876"
  end
  queue.add_bulk("perf", data)
  puts "Done: #{i}"
end
puts "Add done"

count.times do |i|
  val = queue.remove("perf")
  puts "Done: #{i}" if i % 1000 == 0
end
puts "Remove done"