

# time bundle exec ruby spec/performance.rb  
# bundle exec ruby spec/performance.rb 34.83s user 14.28s system 53% cpu 1:32.62 total

$:.push(File.expand_path(File.dirname(__FILE__) + "/../lib"))

require_relative "spec_helper"

queue = MobME::Infrastructure::RedisQueue.new

count = ARGV[0] || 100_000

count.times do |i|
  queue.add("perf", "token#{i}")
end

count.times do |i|
  queue.remove("perf")
end

