# frozen_string_literal: true

module StreamMerger
  # TestUtils
  class Tester
    FIRST_TEST_FILE = "ewbmlXE8Py7L-2024-11-01_19-51-01.198"
    SECOND_TEST_FILE = "ZqueuFbL1FQj-2024-11-01_19-51-01.945"

    attr_reader :conference, :test_files

    def initialize
      @conference = StreamMerger::Conference.new
    end

    def merge
      @test_files = []
      i = 0
      loop do
        add_test_files
        next if execute_test_instructions
        break if i >= 10

        i += 1
        conference.add_black_screen
      end
    end

    def execute_test_instructions
      conference.update(expand_test_files(@test_files)) && conference.execute_instructions
    end

    def add_test_files
      @test_files << get_test_file(FIRST_TEST_FILE)
      @test_files << get_test_file(SECOND_TEST_FILE)
      @test_files = @test_files.compact
    end

    def expand_test_files(files)
      files.map { |f| File.expand_path(f) }
    end

    def get_test_file(file)
      Dir.glob("./spec/fixtures/*").select do |f|
        f.match(file) && f.end_with?(".ts") && !test_files.include?(f)
      end.first
    end
  end
end
