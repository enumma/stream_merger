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

single_stream = StreamMerger::SingleStream.new(handle: "@mauricio",
                                               conference_id: "conference_room_4071daf4-6a8a-4d74-a78b-de4ebdef879a",
                                               stream_id: "participant_03fff6db-4be9-4334-b368-63ebfb964e7f",
                                               stream_keys: [%w[YoutubeStream 6mbf-ve2b-kds3-6s5u-1qc3]])
single_stream.start
sleep 30
loop do
  break unless single_stream.upload_files
end
single_stream.wait_to_finish
single_stream.upload_files
single_stream.kill_processes
