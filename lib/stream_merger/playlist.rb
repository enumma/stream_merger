# frozen_string_literal: true

module StreamMerger
  # Playlist
  class Playlist
    include Utils

    attr_reader :segments, :width, :height, :file_name

    def initialize(file_name:)
      @file_name = file_name
      @segments = []
    end

    def add_segment(file, last_modified)
      segment = build_segment(file, last_modified)
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

    def reorder
      @segments = @segments.sort_by(&:last_modified)
      timestamp = @segments.first.initial_timestamp
      @segments.each do |segment|
        timestamp = segment.set_timestamps(timestamp:)
      end
    end

    private

    attr_reader :tmp

    def build_segment(file, last_modified)
      self.resolution = file if segments.empty?

      return nil if files.include?(file)

      Segment.new(file:, last_modified:)
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
