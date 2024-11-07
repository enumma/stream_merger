# frozen_string_literal: true

module StreamMerger
  # FileLoader
  class FileLoader
    def initialize
      @s3_resource = Aws::S3::Resource.new(StreamMerger.s3_credentials)
      @streams_bucket = @s3_resource.bucket(ENV.fetch("S3_STREAMS_BUCKET"))
    end

    def files
      s3_objects.select { |s| s.key.end_with?("ts") }.first&.public_url
    end

    private

    attr_reader :s3_resource, :streams_bucket

    def s3_objects
      streams_bucket.objects(prefix: "streams/#{stream_id}")
    end
  end
end
