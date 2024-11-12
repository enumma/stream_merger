# frozen_string_literal: true

module StreamMerger
  # Runner
  class Runner
    attr_accessor :hard_stop
    attr_reader :status, :exception

    BREAKER_LIMIT = 150
    BLACK_SCREEN_LIMIT = 20
    HARD_STOP_LIMIT = 20

    def initialize(conference_id: SecureRandom.hex, stream_ids: [])
      @stream_ids = stream_ids
      @file_loader = FileLoader.new(bucket: StreamMerger.streams_bucket)
      @file_uploader = FileUploader.new(conference_id:, bucket: StreamMerger.streams_bucket)
      @conference = StreamMerger::Conference.new(conference_id:)
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
      @upload_thread = Thread.new { upload_files } # Run in a background thread
    end

    def stop
      @thread&.join # Ensure thread completes
      @upload_thread&.join # Ensure thread completes
    end

    def add_stream(stream_id)
      @mutex.synchronize do
        @stream_ids << stream_id unless @stream_ids.include?(stream_id)
      end
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
      wait_for_streams

      loop do
        load_files
        next if execute_instructions

        @loop_breaker += 1
        break if hard_stop? || no_data_for_too_long?

        conference.add_black_screen if @loop_breaker >= BLACK_SCREEN_LIMIT
        sleep 0.5
      end
    rescue StandardError => e
      @exception = e
    ensure
      @running = false
    end

    def upload_files
      loop do
        break if !running? && !@file_uploader.more_files_to_upload?

        @file_uploader.upload_files
      end
      @file_uploader.delete_files
    end

    def execute_instructions
      conference.update(@files) && conference.execute_instructions && (@loop_breaker = 0)
    end

    def load_files
      @mutex.synchronize do
        @files = file_loader.files(@stream_ids) if @stream_ids.any?
      end
    end

    def hard_stop?
      hard_stop && @loop_breaker >= HARD_STOP_LIMIT
    end

    def no_data_for_too_long?
      @loop_breaker >= BREAKER_LIMIT
    end

    def wait_for_streams
      loop do
        break if @stream_ids.any?
        raise Error, "No stream found!" if @loop_breaker >= BREAKER_LIMIT

        @loop_breaker += 1
        sleep 1
      end
      @loop_breaker = 0
    end
  end
end
