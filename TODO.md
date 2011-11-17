
## TODO
* improve performance to at least 10k/s read-write
* selectively tweak a queue (remove or edit items with a specified lkey from a queue)
* write implementation tests and split tests into behavior and implementation.

## CHANGES

### 20111113 (vishnu@mobme.in)
* Initial documentation in Yardoc style.
* Adding #delete_queue(s) to clear & delete any and all queues permanently
* Adding #peek to peek at the first element in a queue without deleting it.
* \#remove is now multi thread and evented systems friendly.
* \#remove can now take a block that will auto add the item back into the queue when an error happens or
  a {MobME::Infrastructure::RedisQueueRemoveAbort} is raised.
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
