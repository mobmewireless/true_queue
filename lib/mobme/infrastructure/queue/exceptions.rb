
class MobME::Infrastructure::Queue::RemoveConflictException < Exception; end

# Raise this to abort a remove and put back the item
class MobME::Infrastructure::Queue::RemoveAbort < Exception; end

