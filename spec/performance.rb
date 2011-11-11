

# bundle exec ruby spec/performance.rb  42.76s user 14.96s system 54% cpu 1:46.19 total

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

