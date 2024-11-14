# frozen_string_literal: true

module StreamMerger
  # Runner
  class Runner
    attr_accessor :hard_stop
    attr_reader :status, :exception

    TIME_LIMIT = 300

    def initialize(conference_id: SecureRandom.hex, stream_ids: [])
      @mutex = Mutex.new                 # Mutex to safely modify stream_ids
      @condition = ConditionVariable.new # Condition variable to signal processing completion
      @processing = false
      @stream_ids = stream_ids
      @file_loader = FileLoader.new(bucket: StreamMerger.streams_bucket)
      @file_uploader = FileUploader.new(conference_id:, bucket: StreamMerger.streams_bucket)
      @conference = StreamMerger::Conference.new(conference_id:)
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
      @mutex.synchronize do
        @running = false
        @condition.signal # Wake up any waiting thread
      end
      @thread&.join # Ensure the background thread completes
      @upload_thread&.join # Ensure thread completes
    end

    def add_stream(stream_id)
      @mutex.synchronize do
        @control_time ||= Time.now
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
        # Skip execution if new stream available before finishing loading files
        next if load_files

        @mutex.synchronize do
          # Wait if a stream is being processed
          @condition.wait(@mutex) while @processing
        end

        if conference.execute
          puts "excecuting"
          puts "-" * 100
          next
        end

        if no_data_for_too_long?
          puts "No data!!!"
          conference.execute(pop: false) # execute remaining safe
          conference.add_black_screen
          if @hard_stop
            sleep 10
            break
          end

          conference.add_black_screen
        end

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

        @file_uploader.upload_files_in_batches
      end
      @file_uploader.delete_files
    end

    def load_files
      current_streams = @stream_ids.dup

      # Start processing
      @mutex.synchronize do
        @processing = true
      end

      files = file_loader.files(@stream_ids) if @stream_ids.any?
      conference.update(files) if files # Slow process

      # Stop processing
      @mutex.synchronize do
        @processing = false
        @condition.signal # Signal `run` to continue
      end

      current_streams != @stream_ids
    end

    def hard_stop?
      hard_stop
    end

    def no_data_for_too_long?
      # No new data
      return (Time.now - @conference.control_time) >= 15 if @conference.control_time

      # Waiting for data to arrive
      return false unless (Time.now - @control_time) >= TIME_LIMIT

      # Data never arrived
      raise Error, "Data never arrived"
    end

    def wait_for_streams
      i = 0
      puts "Wait maximum #{TIME_LIMIT} seconds for streams"
      loop do
        break if @stream_ids.any?
        raise Error, "No stream found!" if i >= TIME_LIMIT

        i += 1
        sleep 1
      end
    end
  end
end
