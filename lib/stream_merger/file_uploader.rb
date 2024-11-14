# frozen_string_literal: true

module StreamMerger
  # FileUploader
  class FileUploader
    DEFAULT_UPLOAD_DIR_TEMPLATE = "./tmp/%<conference_id>s*.{ts,m3u8}"

    def initialize(conference_id:, bucket: ENV.fetch("S3_STREAMS_BUCKET"))
      @s3_resource = Aws::S3::Resource.new(StreamMerger.s3_credentials)
      @streams_bucket = @s3_resource.bucket(bucket)
      @upload_dir = format(DEFAULT_UPLOAD_DIR_TEMPLATE, conference_id: conference_id)
      @uplodaded_files = []
    end

    def upload_files
      files.each { |file| upload_file(file) }
    end

    def upload_files_in_batches(batch_size: 10)
      files.each_slice(batch_size) do |file_batch|
        threads = file_batch.map do |file|
          Thread.new { upload_file(file) }
        end
        threads.each(&:join) # Wait for all threads to finish
      end
    end

    def more_files_to_upload?
      files.any? { |file| !streams_bucket.object("streams/#{File.basename(file)}").exists? }
    end

    def delete_files
      files.each do |file|
        FileUploader.delete_file(file)
      end
    end

    def self.delete_file(file)
      File.delete(file)
      puts "Deleted #{file}"
    rescue Errno::ENOENT => e
      puts "File not found: #{file}, error: #{e.message}"
    rescue StandardError => e
      puts "Failed to delete #{file}: #{e.message}"
    end

    private

    attr_reader :s3_resource, :streams_bucket, :upload_dir

    def files
      Dir.glob(upload_dir).select { |file| !@uplodaded_files.include?(file) }
    end

    def upload_file(file)
      object_key = "streams/#{File.basename(file)}"
      s3_object = streams_bucket.object(object_key)

      if s3_object.exists? && file.match?(/\.ts$/)
        puts "Skipping #{file}, as it already exists in the bucket."
        return
      end

      puts "Uploading #{object_key}..."
      s3_object.upload_file(file)
      puts "Uploaded #{object_key} successfully."
      if file.match?(/\.ts$/)
        @uplodaded_files << file
        FileUploader.delete_file(file)
      end
    rescue Aws::S3::Errors::ServiceError => e
      puts "Failed to upload #{file}: #{e.message}"
    end
  end
end
