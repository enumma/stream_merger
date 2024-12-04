# frozen_string_literal: true

module StreamMerger
  # StreamFile
  class StreamFile
    attr_reader :file_name, :path

    def initialize(file_name:, extension:, type: "tempfile")
      @file_name = file_name
      @type = type
      @file = Tempfile.new([file_name, extension])
      @path = @file.path
      create_fifo if fifo?
      create_normal if normal?
    end

    def dirname
      File.dirname(path)
    end

    def write(item, mode = "w")
      File.open(path, mode) { |f| f.write(item) }
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
      File.chmod(0o666, path)
    rescue StandardError => e
      warn "Failed to create FIFO: #{e.message}"
    end

    def create_normal
      file.close
      file.unlink
      File.open(path, "w") {}
    rescue StandardError => e
      warn "Failed to create Normal: #{e.message}"
    end

    def fifo?
      type == "fifo"
    end

    def normal?
      type == "normal"
    end
  end
end
