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

# Initialize runner
runner = StreamMerger::Runner.new(["wVtG6250NtC5"])
# Start the runner in the background
runner.start
# Add streams dynamically while `run` is executing
runner.add_stream("Rpk4IP1Ss1A5")
# Wait process to finish
loop do
  runner.hard_stop = true # Signal to not include black screen
  break unless runner.running?
end
# Ensure thread completes
runner.stop

# Purge local files
runner.purge!
raise runner.exception if runner.exception
