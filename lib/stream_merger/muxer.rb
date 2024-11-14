# frozen_string_literal: true

module StreamMerger
  # Muxer
  class Muxer
    def initialize
      @mutex = Mutex.new                 # Mutex to safely modify stream_ids
      @condition = ConditionVariable.new # Condition variable to signal processing completion
      @stream_ids = []
      @running = false
      @processing = []
      @files = []
    end

    def start
      return if running?

      @running = true
      @thread = Thread.new { run } # Run in a background thread
    end

    def stop
      @mutex.synchronize do
        @running = false
        @condition.signal          # Wake up any waiting thread
      end
      @thread&.join # Ensure the background thread completes
    end

    def add_stream(stream_id)
      @mutex.synchronize do
        return if @stream_ids.include?(stream_id)

        @stream_ids << stream_id
      end
    end

    def running?
      @running
    end

    private

    attr_reader :stream_ids

    def run
      loop do
        puts "looping"
        break unless running?

        # Load files, and skip the rest of this iteration if `load_files` returns true
        next if load_files

        @mutex.synchronize do
          # Wait if a stream is being processed
          @condition.wait(@mutex) while @processing.any?

          puts "excecuting"
          puts "-" * 100
          # Perform work with the available streams
          puts "Running with streams: #{stream_ids}, processing #{@processing}"
        end
        sleep 1
      end
    ensure
      @running = false
    end

    def add_file(file)
      return if @files.include?(file)

      # Add file to processing queue without holding the mutex during sleep
      @mutex.synchronize do
        @processing << file
        @files << file
      end

      puts "Adding segment #{file}. Processing 5 seconds"
      sleep 5 # Simulate processing time

      # Remove file from processing queue and signal `run` to continue
      @mutex.synchronize do
        @processing.delete(file)
        @condition.signal # Signal `run` to continue
      end
    end

    def load_files
      current_streams = @stream_ids.dup

      @stream_ids.each do |stream_id|
        3.times.each do |index|
          add_file("#{stream_id}_#{index}.ts")
        end
      end

      current_streams != @stream_ids
    end
  end
end
