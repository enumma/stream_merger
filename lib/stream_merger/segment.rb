# frozen_string_literal: true

module StreamMerger
  # Segment
  class Segment
    include Ffmpeg::Utils

    attr_reader :file, :duration, :start, :end

    def initialize(file:, start: file_timestamp(file))
      @file = file
      @duration = ffmpeg_duration(file)
      @start = start
      @end = start + duration.seconds
    end
  end
end
