

# time bundle exec ruby spec/performance.rb  
#
# Perf data:
# bundle exec ruby spec/performance.rb  30.96s user 14.12s system 50% cpu 1:29.99 total
# [15548] 18 Nov 03:01:12 - 1 clients connected (0 slaves), 21763472 bytes in use

$:.push(File.expand_path(File.dirname(__FILE__) + "/../lib"))

require_relative "spec_helper"

queue = MobME::Infrastructure::RedisQueue.new

count = ARGV[0] || 100_000

count.times do |i|
  queue.add("perf", "token-9876")
end

count.times do |i|
  queue.remove("perf")
end

