
require "mobme/infrastructure/redis_queue"
require "mobme/infrastructure/redis_queue/zeromq/persistence_server"

server = MobME::Infrastructure::RedisQueue::ZeroMQ::PersistenceServer.new()
