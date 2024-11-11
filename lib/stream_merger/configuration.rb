# frozen_string_literal: true

module StreamMerger
  # Configuration
  class Configuration
    attr_accessor :s3_credentials, :streams_bucket, :hls_upload_url
  end
end
