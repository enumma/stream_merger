# frozen_string_literal: true

module StreamMerger
  # Playlist
  class Playlist
    include Utils

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

    def header
      <<~HEADER.chomp
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:#{segments.max(&:duration)&.duration&.to_i}
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:EVENT
        #EXT-X-DISCONTINUITY
      HEADER
    end

    def body
      segments.map do |segment|
        "#EXTINF:#{segment.duration},\n#{segment.file}"
      end.join("\n")
    end

    def remove_duplicates
      segments.uniq!(&:file)
    end

    def sort_segments
      segments.sort_by!(&:file)
    end
  end
end
