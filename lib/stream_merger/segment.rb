# frozen_string_literal: true

module StreamMerger
  # Segment
  class Segment
    include Utils

    attr_reader :stream, :file, :duration, :start_time, :end_time, :last_modified

    def initialize(file:, last_modified:, start_time: file_timestamp(file))
      @file = file
      @last_modified = last_modified
      @start_time = start_time
      set_data
    end

    def seconds(timestamp)
      # return 0  if timestamp <= start_time

      timestamp - start_time
    end

    def mkv
      return @mkv if @mkv

      @mkv ||= Tempfile.new([SecureRandom.hex, ".mkv"])
      `ffmpeg -hide_banner -loglevel error -y -i "#{file}" -c:v copy -c:a copy "#{@mkv.path}"`
      @mkv
    end

    private

    attr_reader :timestamp, :tmp

    def set_data
      @timestamp = file_timestamp(file)
      @stream = stream_name(file)
      @duration = ffmpeg_exact_duration(mkv.path)
      # @duration = ffmpeg_duration(file)
      @end_time = start_time + duration.seconds
    end
  end
end
