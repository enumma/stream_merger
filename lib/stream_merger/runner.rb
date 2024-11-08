# frozen_string_literal: true

module StreamMerger
  # Runner
  class Runner
    def initialize(stream_ids = [])
      @stream_ids = stream_ids
      @file_loader = FileLoader.new
      @conference = StreamMerger::Conference.new
      @mutex = Mutex.new # Mutex to safely modify stream_ids
      @running = false
      @loop_breaker = 0
    end

    def start
      return if running?

      @running = true
      @thread = Thread.new { run } # Run in a background thread
    end

    def stop
      @thread&.join # Ensure thread completes
    end

    def add_stream(stream_id)
      @mutex.synchronize { @stream_ids << stream_id }
    end

    def running?
      @running
    end

    def create_mp4
      conference.create_mp4
    end

    def purge!
      conference.purge!
    end

    private

    attr_reader :conference, :file_loader, :files, :stream_ids

    def run
      return unless @stream_ids.any?

      loop do
        load_files
        next if execute_instructions
        break if @loop_breaker >= 10

        conference.add_black_screen
        @loop_breaker += 1
        sleep 1
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
