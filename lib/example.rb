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

runner = StreamMerger::Runner.new
runner.start
loop do
  stream_ids = JSON.parse(`curl -s https://antmedia.test.enumma.com/WebRTCAppEE/rest/v2/broadcasts/list/0/10`).map { |s| s["streamId"] }.reject { |s| s == "room1" }
  stream_ids.each do |stream_id|
    puts "adding stream #{stream_id}"
    runner.add_stream(stream_id)
  end
  break unless runner.running?

  runner.hard_stop = true if stream_ids.any?
  sleep 1 # do not saturate
end

# Ensure thread completes
runner.stop

# Purge local files
runner.purge!
raise runner.exception if runner.exception
