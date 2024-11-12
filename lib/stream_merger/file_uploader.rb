# frozen_string_literal: true

module StreamMerger
  # FileUploader
  class FileUploader
    DEFAULT_UPLOAD_DIR_TEMPLATE = "./tmp/%<conference_id>s*.{ts,m3u8}"

    def initialize(conference_id:, bucket: ENV.fetch("S3_STREAMS_BUCKET"))
      @s3_resource = Aws::S3::Resource.new(StreamMerger.s3_credentials)
      @streams_bucket = @s3_resource.bucket(bucket)
      @upload_dir = format(DEFAULT_UPLOAD_DIR_TEMPLATE, conference_id: conference_id)
    end

    def upload_files
      files.each { |file| upload_file(file) }
    end

    def more_files_to_upload?
      files.any? { |file| !streams_bucket.object("streams/#{File.basename(file)}").exists? }
    end

    def delete_files
      files.each do |file|
        File.delete(file)
        puts "Deleted #{file}"
      rescue Errno::ENOENT => e
        puts "File not found: #{file}, error: #{e.message}"
      rescue StandardError => e
        puts "Failed to delete #{file}: #{e.message}"
      end
    end

    private

    attr_reader :s3_resource, :streams_bucket, :upload_dir

    def files
      Dir.glob(upload_dir)
    end

    def upload_file(file)
      object_key = "streams/#{File.basename(file)}"
      s3_object = streams_bucket.object(object_key)

      if s3_object.exists? && file.match?(/\.ts$/)
        puts "Skipping #{file}, as it already exists in the bucket."
        return
      end

      puts "Uploading #{file}..."
      s3_object.upload_file(file)
      puts "Uploaded #{file} successfully."
    rescue Aws::S3::Errors::ServiceError => e
      puts "Failed to upload #{file}: #{e.message}"
    end
  end
end
