
require "algorithms"

class MobME::Infrastructure::RedisQueue::Memory < MobME::Infrastructure::RedisQueue::Backend
  attr_accessor :scores, :queues

  # Initialises the RedisQueue
  # @param [Hash] options all options to pass to the queue
  def initialize(options = {})
    @queues = {}
  end

  def add(queue, item, metadata = {})
    dequeue_timestamp, priority = extract_options_from_metadata(metadata)
    score = score_from_metadata(dequeue_timestamp, priority)
    
    queues[queue] ||= Containers::CRBTreeMap.new
    queues[queue][score] = serialize_item(item, metadata)
  end
  
  def remove(queue, &block)
    score = queues[queue].min_key
    
    item = item_with_score(queue, score)
    
    #If a block is given
    if block_given?
      begin
        block.call(item)
      rescue MobME::Infrastructure::RedisQueue::RemoveAbort
        return
      end
      queues[queue].delete(score) if item
    else
      queues[queue].delete(score) if item
      return item
    end
  end
  
  def peek(queue)
    score = queues[queue].min_key
    
    item_with_score(queue, score)
  end
  
  def list(queue)
    queues[queue].inject([]) { |collect, step| collect << item_with_score(queue, step[0]) }
  end
  
  def empty(queue)
    queues[queue] = nil
    queues[queue] = Containers::CRBTreeMap.new
  end
  
  def size(queue)
    queues[queue].size
  end
  
  def remove_queues(*queues_to_delete)
    queues_to_delete = list_queues if queues_to_delete.empty?
    queues_to_delete.each do |queue|
      queues.delete(queue)
    end
  end
  alias :remove_queue :remove_queues
  
  def list_queues
    queues.keys
  end
  
  private
  def item_with_score(queue, score)
    item = if not score
      nil
    elsif score > (Time.now.to_f * 1000000).to_i # We don't return future items!
      nil
    else
      value = queues[queue][score]
      unserialize_item(value)
    end
  end
end
