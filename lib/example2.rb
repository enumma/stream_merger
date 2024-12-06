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
  config.videos_bucket = ENV.fetch("S3_VIDEOS_BUCKET")
  config.streams_bucket = ENV.fetch("S3_STREAMS_BUCKET")
end

# runner = StreamMerger::Runner.new(stream_ids: %w[ewbmlXE8Py7L ZqueuFbL1FQj], handle: "@mauricio",
#                                   stream_keys: [%w[YoutubeStream 6mbf-ve2b-kds3-6s5u-1qc3]])
runner = StreamMerger::Runner.new(conference_id: "conference_room_d7ed3d15-d3f1-42e3-8d3f-81c9a502e884",
                                  handle: "@mauricio", stream_ids: %w[participant_ae7a48f5-6f83-4993-b416-e3cced7374e8])
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
