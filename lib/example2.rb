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

runner = StreamMerger::Runner.new(handle: "@mauricio",
                                  conference_id: "conference_room_6f78a218-b9ed-4330-95a8-8fa262608bf4",
                                  stream_keys: [%w[YoutubeStream 6mbf-ve2b-kds3-6s5u-1qc3]],
                                  stream_ids: %w[participant_58ef07b0-8589-4b89-ad9c-462622b3e376
                                                 participant_06ffe308-f563-49ae-855f-4dd8bbb30b53])
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
