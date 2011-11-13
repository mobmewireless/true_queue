
## Overview
Redis Queue is a simple (under 200sloc) but complete queueing system built on top of Redis. It can both schedule and prioritise queued items.

Queues are created when values are added to it. All input is encoded into JSON when stored and decoded when dequeued.

## Dependencies

Redis version 2.4.2 or higher
Ruby version 1.9.2

## Install

    $ bundle install --path vendor

## Spec
    
    $ bundle exec guard

## Usage

### Connect

    redis_queue = RedisQueue.new

### Add an item

    redis_queue.add("publish", {:jobid => 23, :url => 'http://example.com/' })
    
Items can also have arbitrary metadata. They are stored alongside items and returned on a dequeue. 

    redis_queue.add("publish", {:jobid => 23, :url => 'http://example.com/' }, {'importance' => low})

Certain metadata have special meaning. If you set a dequeue-timestamp to a Time object, the item will only be dequeued *after* that time. Note that it won't be dequeued exactly *at* the time, but at any time afterwards.

    # only dequeue 5s after queueing
    redis_queue.add("publish", {:jobid => 23, :url => 'http://example.com/' }, {'dequeue-timestamp' => Time.now + 5 })

Another special metadata keyword is priority.

    # priority is an integer from 1 to 100. Higher priority items are dequeued first.
    redis_queue.add("publish", {:jobid => 23, :url => 'http://example.com/' }, {'priority' => 5})

Items with priority set (or a higher priority) are always dequeued first.

### Remove an item

    # dequeue
    redis_queue.remove("publish")
    
\#remove returns an array. The first element is the Ruby object in the queue, the second is the associated metadata (always a Hash).

    => {:jobid => 23, :url => 'http://example.com/' }, {'priority' => 5}
    
\#remove also can take a block. This is the recommended way to remove an item from a queue.

    # dequeue into a block
    redis_queue.remove do |item|
      #process item
      ...
    end
    
When a block is passed, RedisQueue ensures that the item is put back in case of an error within the block.

Inside a block, you can also manually raise {MobME::Infrastructure::RedisQueueRemoveAbort} to put back the item:

    # dequeue into a block
    redis_queue.remove do |item|
      #this item will be put back
      raise MobME::Infrastructure::RedisQueueRemoveAbort
    end

### List available queues

    redis_queue.list_queues

Returns an array of all queues stored in the Redis instance.

### Remove queues

This empties and removes all queues:

    redis_queue.remove_queues

To selectively remove queues:

    redis_queue.remove_queue "queue1"
    redis_queue.remove_queues "queue1", "queue2"

## Performance

Redis-queue is not written for really high throughput, but see spec/performance.rb. An indicative value is around 200,000 values stored and retrieved in 92s: ~2.1k/s read/write

# {include:file:TODO.md}
