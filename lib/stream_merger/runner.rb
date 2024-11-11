# frozen_string_literal: true

module StreamMerger
  # Runner
  class Runner
    attr_accessor :hard_stop
    attr_reader :status, :exception

    BREAKER_LIMIT = 150

    def initialize(stream_ids = [])
      @stream_ids = stream_ids
      @file_loader = FileLoader.new
      @conference = StreamMerger::Conference.new
      @mutex = Mutex.new # Mutex to safely modify stream_ids
      @running = false
      @loop_breaker = 0
      @exception = nil
      @hard_stop = false
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

    def purge!
      conference.purge!
    end

    private

    attr_reader :conference, :file_loader, :files, :stream_ids

    def run # rubocop:disable Metrics/MethodLength
      return unless @stream_ids.any?

      loop do
        load_files
        if execute_instructions
          @loop_breaker = 0
          next
        end
        break if @loop_breaker >= BREAKER_LIMIT || hard_stop

        conference.add_black_screen
        @loop_breaker += 1
        sleep 0.5
      end
    rescue StandardError => e
      @exception = e
    ensure
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
