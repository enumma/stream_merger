# frozen_string_literal: true

require "active_support/time"
require "json"
require_relative "stream_merger/merger_utils"
require_relative "stream_merger/utils"
require_relative "stream_merger/conference"
require_relative "stream_merger/playlist"
require_relative "stream_merger/segment"
require_relative "stream_merger/tester"
require_relative "stream_merger/version"

# StreamMerger
module StreamMerger
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def s3_credentials
      raise Error, "Empty S3 credentials!" if configuration.s3_credentials.nil?

      configuration.s3_credentials
    end

    def streams_bucket
      raise Error, "Empty S3 credentials!" if configuration.streams_bucket.nil?

      configuration.streams_bucket
    end
  end
end
