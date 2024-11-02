# frozen_string_literal: true

module StreamMerger
  # Playlist
  class Playlist
    include Ffmpeg::Utils

    attr_reader :file, :segments

    def initialize(file:)
      @file = file
      @segments = []
    end

    def <<(segment)
      @segments << segment
      remove_duplicates
      sort_segments
      @segments
    end

    private

    def remove_duplicates
      @segments.uniq!(&:file)
    end

    def sort_segments
      @segments.sort_by!(&:file)
    end
  end
end
