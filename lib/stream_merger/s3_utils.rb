# frozen_string_literal: true

module StreamMerger
  # S3Utils
  module S3Utils
    def s3_resource
      @s3_resource ||= Aws::S3::Resource.new(StreamMerger.s3_credentials)
    end

    def streams_bucket
      @streams_bucket ||= s3_resource.bucket(ENV.fetch("S3_STREAMS_BUCKET"))
    end

    def s3_upload(file, force:)
      path = if file.respond_to?(:path)
               file.path
             else
               file
             end
      base_name = File.basename(path)
      key = "streams/#{base_name}"
      s3_object = streams_bucket.object(key)
      return false if s3_object.exists? && !force

      s3_upload_file(s3_object:, path:)
    end

    def s3_upload_file(s3_object:, path:)
      s3_object.upload_file(path)
      puts "Uploaded #{path}"
      true
    rescue Aws::S3::Errors::ServiceError => e
      puts "Failed to upload #{path}: #{e.message}"
      false
    end
  end
end
