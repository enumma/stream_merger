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
                                  conference_id: "conference_room_7cc72de6-a26b-4e60-923d-fe1fb35b7d5a",
                                  stream_keys: [%w[YoutubeStream 6mbf-ve2b-kds3-6s5u-1qc3]],
                                  stream_ids: %w[participant_01a774ce-0335-4728-837e-ee7e7ce3b509
                                                 participant_a818707e-56e0-4ad2-a692-34826a215f70])
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
