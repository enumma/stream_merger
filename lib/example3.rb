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

single_stream = StreamMerger::SingleStream.new(handle: "@andreszablah",
                                               conference_id: "conference_room_c6daa37a-3178-4b6f-87de-f2ce70266f9f",
                                               stream_id: "participant_09c8daca-03de-4179-96b8-5a1f0a340037",
                                               stream_keys: [])
single_stream.start
thread = Thread.new do
  loop do
    break if !single_stream.upload_files && !single_stream.running?

    sleep 1
  end
end
single_stream.wait_to_finish
single_stream.upload_files
single_stream.kill_processes
thread.join
single_stream.purge!
