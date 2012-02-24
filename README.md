
## Overview

TrueQueue (as in "the one true queue") is a proxy to multiple queueing backends.

The most mature backend is one based on Redis which is a homegrown set of operations over Redis hashes and sorted sets that provides:

* A fast in-memory queue, with constant backups to disk.
* Atomic add and remove operations
* An inspectable queue: you can see what's in the queue or peek into the head of the queue without changing it.
* A reservable remove, where if the client quits halfway, the item is put back in.
* Priority queues
* And delayed retrieval for items, you can set a timestamp after which the entries are slated for removal.

Not to mention the biggest advantage of all: continue to use your existing Redis install!

There are other backends as well: 

* memory: a simple in-process memory queue using a sorted set
* zermoq: an experimental backend built on zeromq (see bin/zeromq-memory-queue.rb)
* amqp: an AMQP backend to work with RabbitMQ

There are a set of uniform conventions regardless of the queue backend used:

* Queues are created when values are added to it. All input is encoded into JSON when stored and decoded when dequeued.
* When a queue is empty, nil is returned on remove
* There are always 9 standard methods: add, add\_bulk, remove, peek, list, empty, size, remove\_queues, list_queues.

Certain features (for e.g. a reservable remove) might not be available on all queue backends.

## Dependencies

Ruby version 1.9.2p290

All other dependencies are in the gemspec

## Install

    $ bundle install --path vendor

## Spec
    
    $ bundle exec guard

## Usage

### Connect

For the redis backend,             
                                   
    queue = TrueQueue.queue(:redis, options = { :redis_options => { } })

For the AMQP backend using bunny,
                                   
    queue = TrueQueue.queue(:amqp, options = { :bunny_options => { } })

For the in-memory backend that only stores keys within a process space,

    queue = TrueQueue.queue(:memory, options = {})
                                   
For the zeromq backend,            
                                   
    queue = TrueQueue.queue(:zeromq, options = {})
                                   
### Add an item

    queue.add("queue_name", {:jobid => 23, :url => 'http://example.com/' })
    
Items can also have arbitrary metadata. They are stored alongside items and returned on a dequeue. 

    queue.add("publish", {:jobid => 23, :url => 'http://example.com/' }, {'importance' => low})

Certain metadata have special meaning. If you set a dequeue-timestamp to a Time object, the item will only be dequeued *after* that time. Note that it won't be dequeued exactly *at* the time, but at any time afterwards.

    # only dequeue 5s after queueing
    queue.add("publish", {:jobid => 23, :url => 'http://example.com/' }, {'dequeue-timestamp' => Time.now + 5 })

Another special metadata keyword is priority.

    # priority is an integer from 1 to 100. Higher priority items are dequeued first.
    queue.add("publish", {:jobid => 23, :url => 'http://example.com/' }, {'priority' => 5})

Items with priority set (or a higher priority) are always dequeued first.

Note that the AMQP backend doesn't support priorities or the dequeue timestamp.

### Remove an item

    # dequeue
    queue.remove("publish")
    
\#remove returns an array. The first element is the Ruby object in the queue, the second is the associated metadata (always a Hash).

    => {:jobid => 23, :url => 'http://example.com/' }, {'priority' => 5}
    
\#remove also can take a block. This is the recommended way to remove an item from a queue.

    # dequeue into a block
    queue.remove do |item|
      #process item
      ...
    end
    
When a block is passed, Queue ensures that the item is put back in case of an error within the block.

Inside a block, you can also manually raise {TrueQueue::RemoveAbort} to put back the item:

    # dequeue into a block
    queue.remove do |item|
      #this item will be put back
      raise TrueQueue::RemoveAbort
    end
    
Note: you cannot pass in a block using the zeromq or amqp queue types.

Another thing to note is that unlike in other queues, **remove does not block and returns nil when the queue is empty**. So you'll have to manually call sleep(delay) and re-poll the queue. This implementation might change in the future:

    loop do	# dequeue into a block
      queue.remove do |item|
	  	next unless item
        #this item will be put back
        raise TrueQueue::RemoveAbort
      end
	  
	  sleep 1
	end
	
### List all items in a queue

This is an expensive operation, but at times, very useful!

    queue.list "queue"

This is not supported for the amqp queue type.

### List available queues

    queue.list_queues

Returns an array of all queues stored in the Redis instance.

### Remove queues

This empties and removes all queues:

    queue.remove_queues

To selectively remove queues:

    queue.remove_queue "queue1"
    queue.remove_queues "queue1", "queue2"

## Performance & Memory Usage

See detailed analysis in spec/performance.

### The Redis Backend

An indicative add performance is around 100,000 values stored in 20s: 5K/s write.

An indicative normal workflow performance is 200,000 values stored and retrieved in 1 minute: ~3K/s read-write

It's also reasonably memory efficient because it uses hashes instead of plain strings to store values. 200,000 values used 20MB (with each value 10 bytes).

### The AMQP Backend

The amqp backend uses the excellent bunny gem to connect to RabbitMQ.

This is slightly slower than the Redis backend: 200,000 values read-write in around 1m30s (~2K/s read-write)

### The Memory Backend

The memory backend only stores keys within the process space.

But performance is *very* good. It does 200,000 read/write in around 5s, which is ~40K/s read/write.

### The ZeroMQ Backend

The zeromq backend is currently experimental. It's meant to do these things:

* Very fast queue adds (5s for 100,000 keys)
* Consistent reads
* Eventual consistency via a persistence server
* A listener based queue interface where a client can request a message rather than messages being pushed down the wire (i.e. 'subscribe' to a queue) (not implemented yet)

