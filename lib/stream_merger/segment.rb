# frozen_string_literal: true

module StreamMerger
  # Segment
  class Segment
    include Utils

    attr_reader :file, :duration, :start_time, :end_time

    def initialize(file:, start_time: file_timestamp(file))
      @file = file

      @start_time = start_time
      set_data
    end

    def seconds(timestamp)
      timestamp - start_time
    end

    def mkv
      return @mkv if @mkv

      @mkv ||= Tempfile.new([SecureRandom.hex, ".mkv"])
      `ffmpeg -y -i "#{file}" -c:v copy -c:a copy "#{@mkv.path}"`
      @mkv
    end

    private

    attr_reader :timestamp, :tmp

    def set_data
      @timestamp = file_timestamp(file)
      @duration = ffmpeg_duration(mkv.path)
      # @duration = ffmpeg_duration(file)
      @end_time = start_time + duration.seconds
    end
  end
end
