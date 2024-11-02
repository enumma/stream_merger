# frozen_string_literal: true

module StreamMerger
  # Segment
  class Segment
    include Ffmpeg::Utils

    attr_reader :duration

    def initialize(file:)
      @file = file
      @duration = ffmpeg_duration(file)
    end

    private

    attr_reader :file
  end
end
