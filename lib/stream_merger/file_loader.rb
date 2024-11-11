# frozen_string_literal: true

module StreamMerger
  # FileLoader
  class FileLoader
    def initialize(bucket: ENV.fetch("S3_STREAMS_BUCKET"))
      @s3_resource = Aws::S3::Resource.new(StreamMerger.s3_credentials)
      @streams_bucket = @s3_resource.bucket(bucket)
    end

    def files(stream_ids)
      urls = []
      s3_objects(stream_ids).each do |collection|
        urls += collection.map(&:public_url)
      end
      urls
    end

    private

    attr_reader :s3_resource, :streams_bucket

    def s3_objects(stream_ids)
      stream_ids.map do |stream_id|
        objects = streams_bucket.objects(prefix: "streams/#{stream_id}").select { |s| s.key.match(".ts") }
        objects
      end
    end
  end
end
