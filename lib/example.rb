# frozen_string_literal: true

require_relative "stream_merger"
require "dotenv/load"
# Configure Gem
StreamMerger.configure do |config|
  config.s3_credentials = {
    region: "us-east-1",
    access_key_id: ENV.fetch("AWS_ACCESS_KEY"),
    secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY")
  }
  config.streams_bucket = ENV.fetch("S3_STREAMS_BUCKET")
end
# Run merger
runner = StreamMerger::Runner.new
runner.stream_ids = %w[ewbmlXE8Py7L ZqueuFbL1FQj]
runner.run
