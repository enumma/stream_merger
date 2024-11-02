# frozen_string_literal: true

module StreamMerger
  # Segment
  class Segment
    include Ffmpeg::Utils

    attr_reader :duration, :start, :end

    def initialize(file:, start: file_timestamp(file))
      @file = file
      @duration = ffmpeg_duration(file)
      @start = start
      @end = start + duration.seconds
    end

    private

    attr_reader :file
  end
end
