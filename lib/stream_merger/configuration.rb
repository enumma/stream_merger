# frozen_string_literal: true

module StreamMerger
  # Configuration
  class Configuration
    attr_accessor :s3_credentials, :videos_bucket, :streams_bucket
  end
end
