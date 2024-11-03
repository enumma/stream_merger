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

    private

    attr_reader :timestamp

    def set_data
      @timestamp = file_timestamp(file)
      @duration = ffmpeg_exact_duration(file)
      @end_time = start_time + duration.seconds
    end
  end
end
