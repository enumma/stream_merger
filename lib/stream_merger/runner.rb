# frozen_string_literal: true

module StreamMerger
  # Runner
  class Runner
    attr_reader :running

    def initialize(stream_ids = [])
      @stream_ids = stream_ids
      @file_loader = FileLoader.new
      @conference = StreamMerger::Conference.new
      @mutex = Mutex.new # Mutex to safely modify stream_ids
      @running = false
      @loop_breaker = 0
    end

    def start
      return if running

      @thread = Thread.new { run } # Run in a background thread
    end

    def stop
      @running = false
      @thread&.join # Ensure thread completes
    end

    def add_stream(stream_id)
      @mutex.synchronize { @stream_ids << stream_id }
    end

    private

    attr_reader :conference, :file_loader, :files, :stream_ids

    def run
      return unless @stream_ids.any?

      @running = true
      loop do
        load_files
        next if execute_instructions
        break if @loop_breaker >= 10

        conference.add_black_screen
        @loop_breaker += 1
      end
      @running = false
    end

    def execute_instructions
      conference.update(@files) && conference.execute_instructions
    end

    def load_files
      @mutex.synchronize do
        @files = file_loader.files(@stream_ids) if @stream_ids.any?
      end
    end
  end
end
