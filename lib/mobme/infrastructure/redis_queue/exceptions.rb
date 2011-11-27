
class MobME::Infrastructure::RedisQueue::RemoveConflictException < Exception; end

# Raise this to abort a remove and put back the item
class MobME::Infrastructure::RedisQueue::RemoveAbort < Exception; end

