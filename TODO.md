
## TODO
* zeromq-memory-queue:
  * should store last ACK-ed at
  * should expose a method to get at its stats
    * read/s
    * write/s
    * transactions/s
    * queue lengths
    * memory used
    * last ACK received time
* selectively tweak a queue (remove or edit items with a specified lkey from a queue)
* write tests that checks for contention cases, when we have a lot of queues, queue items and workers.
* flesh out the tests more for every edge case.
* write implementation tests and split tests into behavior and implementation.

## CHANGES

### 20120224 (vishnu@mobme.in)
* TrueQueue

### 20111203 (vishnu@mobme.in)
* Renaming redis_queue to queue

### 20111201 (vishnu@mobme.in)
* A persistence server for the zeromq queue based on redis
  * The persistence server requests backlogs from the memory queue and 
    stores updates in Redis
  * The persistence server sents an ACK for a backlog which says Redis
    processing has been successful.
* The memory queue maintains a backlog of updates for which it hasn't received
  an ACK.

### 20111130 (vishnu@mobme.in)
* An experimental zeromq backend and queue server.

### 20111128 (vishnu@mobme.in)
* Modularizing the code so that we can now use multiple backends.
* A memory based queue backend based on a C red-black tree implementation.
* BREAKING. Queues are now created using:
    MobME::Infrastructure::RedisQueue.queue(backend) where backend is either one of :memory or :redis now.

### 20111118 (vishnu@mobme.in)
* Store values inside small key-ed hashes for maximum memory efficiency.
* Major reorganization, making everything far more modular & simple.

### 20111113 (vishnu@mobme.in)
* Initial documentation in Yardoc style.
* Adding #delete_queue(s) to clear & delete any and all queues permanently
* Adding #peek to peek at the first element in a queue without deleting it.
* \#remove is now multi thread and evented systems friendly.
* \#remove can now take a block that will auto add the item back into the queue when an error happens or a {MobME::Infrastructure::RedisQueueRemoveAbort} is raised.
* \#list to list every element in the queue. This is an expensive operation.
* Renaming #clear to #empty
* Renaming #delete\_queue(s) to #remove\_queue(s)
* More comprehensive documentation in README.md and TODO.md
* Using Yajl instead of native JSON
* Gemifying

### 20111111 (vishnu@mobme.in)
* Organized the project into the formal MobME ruby tdd template
* Wrote initial specs for everything implemented.

### Date Uncertain
* -- initial release --
