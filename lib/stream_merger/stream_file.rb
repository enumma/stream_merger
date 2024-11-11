# frozen_string_literal: true

module StreamMerger
  # StreamFile
  class StreamFile
    attr_reader :path

    def initialize(file_name:, extension:, type: "tempfile")
      @type = type
      @file = Tempfile.new([file_name, extension])
      @path = @file.path
      puts @path
      create_fifo if fifo?
    end

    def write(item, mode = "w")
      File.open(path, mode) { |fifo| fifo.write(item) }
    end

    def delete
      File.delete(path) if File.exist?(path)
    end

    private

    attr_reader :file, :type

    def create_fifo
      file.close
      file.unlink
      File.mkfifo(path)
    rescue StandardError => e
      warn "Failed to create FIFO: #{e.message}"
    end

    def fifo?
      type == "fifo"
    end
  end
end
