# frozen_string_literal: true

module StreamMerger
  # Configuration
  class Configuration
    attr_accessor :s3_credentials, :streams_bucket
  end
end
