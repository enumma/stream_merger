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
                                               conference_id: "conference_room_b7ef406a-83e3-4a6f-a40d-5d852f40bea3",
                                               stream_id: "participant_8d9c80fc-0b93-42e1-a1bd-ff41ff6ea26f",
                                               stream_keys: [%w[YoutubeStream 6mbf-ve2b-kds3-6s5u-1qc3]])
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
