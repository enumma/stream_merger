# frozen_string_literal: true

module StreamMerger
  # FileUploader
  class FileUploader
    include S3Utils
    UPLOAD_DIR_TEMPLATE = "%<dirname>s/%<file_name>s*.{ts,m3u8}"

    def initialize(main_m3u8:)
      @main_m3u8 = main_m3u8
      dirname = File.dirname(main_m3u8.path)
      file_name = main_m3u8.file_name.split("Merged").first
      @upload_dir = format(UPLOAD_DIR_TEMPLATE, dirname:, file_name:)
      @uploaded_files = []
    end

    def upload_files_in_batches(batch_size: 100)
      pending_files.each_slice(batch_size) do |file_batch|
        threads = file_batch.map do |file|
          Thread.new { upload_file(file) }
        end
        threads.each(&:join) # Wait for all threads to finish
      end
    end

    def more_files_to_upload?
      pending_files.any? { |file| !videos_bucket.object("streams/#{File.basename(file)}").exists? }
    end

    def delete_files
      files.each do |file|
        delete_file(file)
      end
    end

    private

    attr_reader :upload_dir

    def files
      Dir.glob(upload_dir)
    end

    def pending_files
      files.reject { |file| @uploaded_files.include?(file) || file.end_with?(".m3u8") }
    end

    def upload_file(file)
      upload_to_s3(@main_m3u8, force: true) if upload_to_s3(file, force: false)

      return if !file.match?(/\.ts$/) || @uploaded_files.include?(file)

      @uploaded_files << file
      # delete_file(file)
    end

    def upload_to_s3(file, force:)
      if file.respond_to?(:file_name)
        path = file.path
        base_name = file.file_name + File.extname(file.path)
      else
        path = file
        base_name = File.basename(path)
      end
      s3_upload(base_name:, path:, force:)
    end

    def delete_file(file)
      File.delete(file) if File.exist?(file)
    rescue StandardError => e
      puts "Failed to delete #{file}: #{e.message}"
    end
  end
end
