# frozen_string_literal: true

module StreamMerger
  # Tester
  class Tester
    FIRST_FILE = "ewbmlXE8Py7L-2024-11-01_19-51-01.198"
    SECOND_FILE = "ZqueuFbL1FQj-2024-11-01_19-51-01.945"

    attr_reader :conference, :files

    def initialize
      @conference = StreamMerger::Conference.new
    end

    def run
      @files = []
      i = 0
      loop do
        add_files
        next if execute_instructions
        break if i >= 10

        conference.add_black_screen
        i += 1
      end
    end

    private

    def execute_instructions
      conference.update(expand_files(@files)) && conference.execute_instructions
    end

    def add_files
      @files << get_file(FIRST_FILE)
      @files << get_file(SECOND_FILE)
      @files = @files.compact
    end

    def expand_files(files)
      files.map { |f| File.expand_path(f) }
    end

    def get_file(file)
      Dir.glob("./spec/fixtures/*").select do |f|
        f.match(file) && f.end_with?(".ts") && !files.include?(f)
      end.first
    end
  end
end
