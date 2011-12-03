
module MobME::Infrastructure::Queue
  module Backends
  end
end

class MobME::Infrastructure::Queue::Backend  
protected
  def score_from_metadata(dequeue_timestamp, priority)
    if dequeue_timestamp
      (dequeue_timestamp.to_f * 1000000).to_i
    else
      ((Time.now.to_f * 1000000).to_i) / (priority || 1)
    end
  end
  
  def normalize_metadata(metadata)
    dequeue_timestamp = metadata['dequeue-timestamp']
    if dequeue_timestamp
      unless dequeue_timestamp.is_a? Time
        metadata['dequeue-timestamp'] = Time.now
      end
    end

    priority = metadata['priority']
    if priority
      priority = priority.to_i
      unless priority.between?(1, 100)
        metadata['priority'] = 1
      end
    end
    
    metadata
  end
  
  def serialize_item(item, metadata)
    Yajl.dump([item, metadata])
  end
  
  def unserialize_item(value)
    json_value = value || Yajl.dump(value) #handle nil to null
    Yajl.load(json_value)
  end
end

