# frozen_string_literal: true

require "aws-sdk-s3"
require "active_support/time"
require "json"
require "securerandom"
require "tempfile"
require "time"
require_relative "stream_merger/concat"
require_relative "stream_merger/merger_utils"
require_relative "stream_merger/stream_file"
require_relative "stream_merger/utils"
require_relative "stream_merger/conference"
require_relative "stream_merger/configuration"
require_relative "stream_merger/file_loader"
require_relative "stream_merger/playlist"
require_relative "stream_merger/segment"
require_relative "stream_merger/runner"
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

    def hls_upload_url
      raise Error, "Empty HLS upload url!" if configuration.hls_upload_url.nil?
      raise Error, "Invalid HLS upload url" unless valid_url?(configuration.hls_upload_url)

      configuration.hls_upload_url
    end

    def valid_url?(string)
      uri = URI.parse(string)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end
  end
end
