# frozen_string_literal: true

module StreamMerger
  # FileUploader
  class FileUploader
    UPLOAD_DIR_TEMPLATE = "%<dirname>s/%<conference_id>s*.{ts,m3u8}"

    def initialize(main_m3u8:, conference_id:, bucket: ENV.fetch("S3_STREAMS_BUCKET"))
      @s3_resource = Aws::S3::Resource.new(StreamMerger.s3_credentials)
      @streams_bucket = @s3_resource.bucket(bucket)
      @main_m3u8 = main_m3u8
      dirname = File.dirname(main_m3u8.path)
      @upload_dir = format(UPLOAD_DIR_TEMPLATE, dirname:, conference_id: conference_id)
      @uploaded_files = []
    end

    def upload_files_in_batches(batch_size: 100)
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
        delete_file(file)
      end
    end

    private

    attr_reader :s3_resource, :streams_bucket, :upload_dir

    def files
      Dir.glob(upload_dir).reject { |file| @uploaded_files.include?(file) }
    end

    def upload_file(file)
      upload_manifest if upload_ts_segment(file:)

      return if !file.match?(/\.ts$/) || @uploaded_files.include?(file)

      @uploaded_files << file
      delete_file(file)
    end

    def upload_manifest
      object_key = "streams/#{File.basename(@main_m3u8.path)}"
      s3_object = streams_bucket.object(object_key)
      s3_object.upload_file(@main_m3u8.path)
      puts "Uploaded #{object_key} successfully."
    rescue Aws::S3::Errors::ServiceError => e
      puts "Failed to upload #{file}: #{e.message}"
    end

    def upload_ts_segment(file:)
      return unless file.match?(/\.ts$/)

      object_key = "streams/#{File.basename(file)}"
      s3_object = streams_bucket.object(object_key)

      return if s3_object.exists?

      s3_object.upload_file(file)
      puts "Uploaded #{object_key} successfully."
      true
    rescue Aws::S3::Errors::ServiceError => e
      puts "Failed to upload #{file}: #{e.message}"
    end

    def delete_file(file)
      File.delete(file) if File.exist?(file)
    rescue StandardError => e
      puts "Failed to delete #{file}: #{e.message}"
    end
  end
end
