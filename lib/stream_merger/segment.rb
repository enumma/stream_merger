# frozen_string_literal: true

module StreamMerger
  # Segment
  class Segment
    include Utils

    attr_reader :file, :start_time, :end_time, :last_modified, :mkv, :duration

    def initialize(file:, last_modified:)
      @file = file
      @last_modified = last_modified
      set_mkv
    end

    def set_timestamps(timestamp:)
      @start_time = timestamp
      @end_time = timestamp + duration.seconds
    end

    def seconds(timestamp)
      timestamp - start_time
    end

    def initial_timestamp
      file_timestamp(file)
    end

    private

    def set_mkv
      @mkv = Tempfile.new([SecureRandom.hex, ".mkv"])
      `ffmpeg -hide_banner -loglevel error -y -i "#{file}" -c:v copy -c:a copy "#{@mkv.path}"`
      @duration = ffmpeg_exact_duration(@mkv.path)
    end
  end
end
