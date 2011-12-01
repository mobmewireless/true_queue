
require 'ffi-rzmq'
require 'mobme/infrastructure/redis_queue/zeromq/connection_handler'
require 'redis/connection/synchrony'
require 'digest/sha1'
require 'fileutils'

module MobME::Infrastructure::RedisQueue::ZeroMQ
  class PersistenceServer
    def initialize(options = {})
      @queue = MobME::Infrastructure::RedisQueue.queue(:redis)
      @persistence_socket = options[:persistence_socket] || "ipc:///tmp/mobme-infrastructure-queue-persistence.sock"
      @persistence_store_path = options[:persistence_store_path] || "/tmp"
      @backlog_interval = options[:backlog_interval] || 10
      
      EM.synchrony do
        create_snapshot_directory
        bind
        
        send_backlog_requests
      end
    end
    
    def bind
      @context = EM::ZeroMQ::Context.new(1)
      
      @persistence_request_server = @context.connect(ZMQ::REQ, @persistence_socket)
    end
    
    def send_backlog_requests
      loop do
        handler = MobME::Infrastructure::RedisQueue::ZeroMQ::ConnectionHandler.new(@persistence_request_server)
        handler.send_message Marshal.dump("BACKLOG")
        puts "Sent BACKLOG"
        
        snapshot = handler.receive_message
        snapshot = Marshal.load(snapshot) rescue nil
        
        case snapshot
        when nil
        when false
        else
          dump_snapshot_to_disk(snapshot)
          
          if snapshot and !snapshot.empty?
            handler.send_message Marshal.dump("ACK #{ack_signature(snapshot)}")
          
            # We get an OK back from the server
            handler.receive_message
          end
        end
        
        EM::Synchrony.sleep(@backlog_interval)
      end
    end
    
    private 
    def create_snapshot_directory
      @persistence_store_path = Pathname.new(@persistence_store_path).join("db")
      FileUtils.mkdir_p(@persistence_store_path)
    end
    
    def dump_snapshot_to_disk(snapshot)
      snapshot.each do |queue, items|
        puts "Snapshotting: #{queue}"
        marshalled_items = StringIO.new(Marshal.dump(items))
        File.open(@persistence_store_path.join("#{queue}.marshal"), "w+") do |file|
          file.write marshalled_items.read
        end
        puts "Done."
      end
    end
    
    def ack_signature(snapshot)
      marshaled_snapshot = Marshal.dump(snapshot)
      Digest::SHA1.hexdigest(marshaled_snapshot)
    end
  end
end
