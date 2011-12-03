

# time bundle exec ruby spec/performance/amqp.rb  
#
# Perf data:
# bundle exec ruby spec/performance/amqp.rb  68.61s user 8.31s system 84% cpu 1:31.19 total

$:.push(File.expand_path(File.dirname(__FILE__) + "/../../lib"))

require_relative "../spec_helper"

queue = MobME::Infrastructure::Queue.queue(:amqp)
count = ARGV[0] || 100_000

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
