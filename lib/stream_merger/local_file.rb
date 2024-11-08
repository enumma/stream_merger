# frozen_string_literal: true

module StreamMerger
  # LocalFile
  class LocalFile
    attr_accessor :path

    def initialize(file_name, path = "./lib/tmp")
      @relative_path = "#{path}/#{file_name}"
      @file = File.open(relative_path, "a") # create empty file
      @path = File.expand_path(relative_path)
    end

    def write(item)
      file.rewind
      file.write(item)
      file.rewind
    end

    def delete
      File.open(relative_path, "r") do |f|
        File.delete(f)
      end
    rescue Errno::ENOENT => e
      puts e.message
    end

    private

    attr_reader :relative_path, :file
  end
end
