# frozen_string_literal: true

module StreamMerger
  # FileLoader
  class FileLoader
    include StreamMerger::S3Utils
    def initialize
      @loaded_files = {}
    end

    def files(stream_ids)
      urls = []
      s3_objects(stream_ids).each do |file|
        urls << [file.public_url, file.last_modified] unless @loaded_files.key?(file.key)
        @loaded_files[file.key] = file.public_url
      end
      urls.sort_by { |_url, last_modified| last_modified }
    end

    private

    def s3_objects(stream_ids)
      stream_ids.flat_map do |stream_id|
        streams_bucket.objects(prefix: "streams/#{stream_id}").select do |s|
          s.key.match?(/\.ts/) && !@loaded_files.key?(s.key)
        end
      end
    end
  end
end
