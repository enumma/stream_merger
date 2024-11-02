# frozen_string_literal: true

module StreamMerger
  # Segment
  class Segment
    include Utils

    attr_reader :file, :duration, :start, :end

    def initialize(file:, start: file_timestamp(file))
      @file = file
      @start = start
      set_data
    end

    private

    attr_reader :timestamp

    def set_data
      @timestamp = file_timestamp(file)
      @duration = ffmpeg_exact_duration(file)
      @end = start + duration.seconds
    end
  end
end
