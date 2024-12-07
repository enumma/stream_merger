# frozen_string_literal: true

module StreamMerger
  # Runner
  class Runner # rubocop:disable Metrics/ClassLength
    attr_accessor :hard_stop
    attr_reader :status, :exception

    TIME_LIMIT = 600

    def initialize(conference_id: SecureRandom.hex, stream_ids: [], handle: nil, stream_keys: [])
      @mutex = Mutex.new                 # Mutex to safely modify stream_ids
      @condition = ConditionVariable.new # Condition variable to signal processing completion
      @processing = false
      @stream_ids = stream_ids
      @file_loader = FileLoader.new
      @conference = Conference.new(conference_id:, handle:, stream_keys:)
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

    def run # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      wait_for_streams

      loop do
        # Skip execution if new stream available before finishing loading files
        next if load_files

        @mutex.synchronize do
          # Wait if a stream is being processed
          @condition.wait(@mutex) while @processing
        end

        next if conference.execute

        if no_data_for_too_long?
          next if conference.execute(pop: false) # execute remaining safe

          if @hard_stop
            conference.add_black_screen(finish: true)
            conference.wait_to_finish
            break
          else
            conference.add_black_screen
          end
        end

        sleep 1 # Do not saturate FileLoader
      end
    rescue StandardError => e
      @exception = e
    ensure
      @running = false
    end

    def upload_files
      loop do
        break if !@conference.upload_files && !running?

        sleep 1
      end
    end

    def load_files # rubocop:disable Metrics/MethodLength
      current_streams = @stream_ids.dup

      # Start processing
      @mutex.synchronize do
        @processing = true
      end

      files = file_loader.files(@stream_ids) if @stream_ids.any?
      # Slow process
      files&.each_slice(10) do |batch|
        conference.update(batch)
      end

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

    def no_data_for_too_long? # rubocop:disable Metrics/AbcSize
      # No new data
      return (Time.now.to_f - @conference.control_time.to_f) >= 5 if @conference.control_time
      return (Time.now.to_f - @control_time.to_f) >= 50 if @conference.segments.any?

      # Waiting for data to arrive
      return false unless (Time.now.to_f - @control_time.to_f) >= TIME_LIMIT

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
