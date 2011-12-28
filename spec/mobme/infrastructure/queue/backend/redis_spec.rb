require_relative '../../../../spec_helper'
require_relative 'queue_behavior'
require_relative 'reserved_queue_behavior'

puts "Specs require a Redis client running on the default port."

require 'mobme/infrastructure/queue/backends/redis'

describe MobME::Infrastructure::Queue::Backends::Redis do
  let(:queue) { MobME::Infrastructure::Queue.queue(:redis) }
  
  it_behaves_like "a queue"
  it_behaves_like "a reserved queue"

  context "in the presence of network delays" do
    class MobME::Infrastructure::Queue::Backends::Redis
      alias_method :write_value_original, :write_value
    end

    describe "#add" do
      before :each do
        queue.empty 'queue'
        queue.stub(:generate_uuid).and_return(1)
        queue.stub(:write_value) { |*args|
          sleep 0.4
          queue.send(:write_value_original, *args)
        }
      end

      it "does not yield item until value is properly stored" do
        adding_thread = Thread.new { queue.add 'queue', 'thrift' }

        removing_thread = Thread.new do
          extracted_items = []

          while extracted_items.empty?
            queue.remove('queue') do |item|
              extracted_items << item
            end

            sleep 0.1
          end

          extracted_items.should_not include(nil)
        end

        adding_thread.join
        removing_thread.join
      end
    end
  end
end
