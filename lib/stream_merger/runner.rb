# frozen_string_literal: true

module StreamMerger
  # TestUtils
  class Runner
    attr_accessor :stream_ids

    def initialize
      @stream_ids = []
      @file_loader = FileLoader.new
      @conference = StreamMerger::Conference.new
    end

    def run
      return unless @stream_ids.any?

      i = 0
      loop do
        load_files
        next if execute_instructions
        break if i >= 10

        conference.add_black_screen
        i += 1
      end
    end

    private

    attr_reader :conference, :file_loader, :files

    def execute_instructions
      conference.update(@files) && conference.execute_instructions
    end

    def load_files
      @files = file_loader.files(stream_ids)
    end
  end
end
