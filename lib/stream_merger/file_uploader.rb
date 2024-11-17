# frozen_string_literal: true

module StreamMerger
  # FileUploader
  class FileUploader
    include S3Utils
    UPLOAD_DIR_TEMPLATE = "%<dirname>s/%<conference_id>s*.{ts,m3u8}"

    def initialize(main_m3u8:, conference_id:)
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

    attr_reader :upload_dir

    def files
      Dir.glob(upload_dir).reject { |file| @uploaded_files.include?(file) }
    end

    def upload_file(file)
      s3_upload(@main_m3u8, force: true) if s3_upload(file, force: false)

      return if !file.match?(/\.ts$/) || @uploaded_files.include?(file)

      @uploaded_files << file
      delete_file(file)
    end

    def delete_file(file)
      File.delete(file) if File.exist?(file)
    rescue StandardError => e
      puts "Failed to delete #{file}: #{e.message}"
    end
  end
end
