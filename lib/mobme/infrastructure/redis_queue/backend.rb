
class MobME::Infrastructure::RedisQueue::Backend

protected
  def score_from_metadata(dequeue_timestamp, priority)
    if dequeue_timestamp
      (dequeue_timestamp.to_f * 1000000).to_i
    else
      ((Time.now.to_f * 1000000).to_i) / (priority || 1)
    end
  end
  
  def extract_options_from_metadata(metadata)
    if dequeue_timestamp = metadata['dequeue-timestamp']
      unless dequeue_timestamp.is_a? Time
        raise ArgumentError, "dequeue-timestamp must be an instance of Time, but #{dequeue_timestamp.class} given"
      end
    end

    if priority = metadata['priority']
      unless (priority.is_a? Integer) && priority.between?(1, 100)
        raise ArgumentError, "priority must be an Integer between 1 and 100, but #{priority.class} given"
      end
    end
    
    [dequeue_timestamp, priority]
  end
  
  def serialize_item(item, metadata)
    Yajl.dump([item, metadata])
  end
  
  def unserialize_item(value)
    json_value = value || Yajl.dump(value) #handle nil to null
    Yajl.load(json_value)
  end
end

