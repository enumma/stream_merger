# frozen_string_literal: true

module StreamMerger
  # Segment
  class Segment
    include Utils

    MANIFEST_REGEX = /.+\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.\d{3}/

    attr_reader :file, :duration, :start, :end

    def initialize(file:, start: file_timestamp(file))
      @file = file
      @start = start
      set_data
    end

    def manifest
      "#{File.basename(file)[MANIFEST_REGEX]}.m3u8"
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
