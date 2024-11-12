# frozen_string_literal: true

module StreamMerger
  # FileLoader
  class FileLoader
    def initialize(bucket: ENV.fetch("S3_STREAMS_BUCKET"))
      @s3_resource = Aws::S3::Resource.new(StreamMerger.s3_credentials)
      @streams_bucket = @s3_resource.bucket(bucket)
      @loaded_files = {}
    end

    def files(stream_ids)
      urls = []
      s3_objects(stream_ids).each do |file|
        urls << file.public_url unless @loaded_files.key?(file.key)
        @loaded_files[file.key] = file.public_url
      end
      urls
    end

    private

    attr_reader :s3_resource, :streams_bucket

    def s3_objects(stream_ids)
      stream_ids.flat_map do |stream_id|
        streams_bucket.objects(prefix: "streams/#{stream_id}").select do |s|
          s.key.match?(".ts") && !@loaded_files.key?(s.key)
        end
      end
    end
  end
end
