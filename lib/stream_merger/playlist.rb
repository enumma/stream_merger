# frozen_string_literal: true

module StreamMerger
  # Playlist
  class Playlist
    require "tempfile"
    include Utils

    attr_reader :segments, :width, :height, :file_name

    def initialize(file_name:)
      @file_name = file_name
      @segments = []
    end

    def <<(file)
      segment = build_segment(file)
      return nil unless segment

      @segments << segment
      @segments
    end

    def start_time
      segments.first.start_time
    end

    def end_time
      segments.last.end_time
    end

    def segment(start_time, end_time)
      segments.select { |s| s.start_time < end_time && s.end_time > start_time }.last
    end

    private

    attr_reader :tmp

    def build_segment(file)
      if segments.empty?
        self.resolution = file
        return Segment.new(file:)
      end

      return nil if files.include?(file)

      Segment.new(file:, start_time: segments.last.end_time)
    end

    def files
      segments.map(&:file)
    end

    def resolution=(file)
      return if @width && @height

      h = ffmpeg_resolution(file)
      @width = h[:width]
      @height = h[:height]
    end
  end
end
