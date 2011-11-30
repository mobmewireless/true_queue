
require "mobme/infrastructure/redis_queue"
require "mobme/infrastructure/redis_queue/zeromq/server"

server = MobME::Infrastructure::RedisQueue::ZeroMQ::Server.new()
