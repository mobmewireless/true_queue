

# time bundle exec ruby spec/performance/zeromq.rb  
#
# Perf data (just adds):
# bundle exec ruby spec/performance/zeromq.rb  1.47s user 0.40s system 36% cpu 5.100 total
# Perf data (both adds and removes):
# bundle exec ruby spec/performance/zeromq.rb  26.06s user 13.06s system 54% cpu 1:11.77 total

$:.push(File.expand_path(File.dirname(__FILE__) + "/../../lib"))

require "em-synchrony"
require_relative "../spec_helper"

EM.synchrony do
  queue = MobME::Infrastructure::RedisQueue.queue(:zeromq)
  count = ARGV[0] || 100_000
  
  # This is the simple add:
  # count.times do |i|
  #   queue.add("perf", "token-9876")
  #   puts "Done: #{i}" if i % 1000 == 0
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
  
  EM.stop
end

