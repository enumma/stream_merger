# frozen_string_literal: true

require_relative "stream_merger"
require "dotenv/load"
require "byebug"
# Configure Gem
StreamMerger.configure do |config|
  config.s3_credentials = {
    region: "us-east-1",
    access_key_id: ENV.fetch("AWS_ACCESS_KEY"),
    secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY")
  }
  config.streams_bucket = ENV.fetch("S3_STREAMS_BUCKET")
end

runner = StreamMerger::Runner.new(stream_ids: %w[ewbmlXE8Py7L ZqueuFbL1FQj], handle: "@mauricio",
                                  stream_key: "7dy2-gsj2-m7rk-8j0a-7vxk")
# runner = StreamMerger::Runner.new(stream_ids: %w[E3ivaecEHlJr ZOm21G0irMQh diTBkWXcZ5xJ veAAQNHlk7EV])
runner.start
loop do
  break unless runner.running?

  runner.hard_stop = true
  sleep 1
end

# Ensure thread completes
runner.stop

# Purge local files
runner.purge!
raise runner.exception if runner.exception