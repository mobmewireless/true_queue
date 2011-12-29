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

  describe "Contention Test" do
    before :each do
      queue.empty 'testing.parallel.addition.and.removal'
    end

    it "adds and removes in parallel without losing items" do
      adders = (1..3).map do |adder_count|
        Thread.new do
          (1..(111*adder_count)).each do |x|
            queue.add('testing.parallel.addition.and.removal', {"value_#{adder_count}" => x})
          end
        end
      end

      removed = {"1" => [], "2" => [], "3" => []}

      removers = (1..2).map do |remover_count|
        Thread.new do
          while(removed["1"].count < 111 || removed["2"].count < 222 || removed["3"].count < 333) do
            queue.remove('testing.parallel.addition.and.removal') do |item|
              key = item.first.keys.first
              remove_queue_number = key.split('_').last
              removed[remove_queue_number] << item
            end
          end
        end
      end

      adders.each { |adder| adder.join }
      removers.each { |remover| remover.join }

      removed["1"].uniq.count.should == 111
      removed["2"].uniq.count.should == 222
      removed["3"].uniq.count.should == 333
    end
  end
end
