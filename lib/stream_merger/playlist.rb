# frozen_string_literal: true

module StreamMerger
  # Playlist
  class Playlist
    require "tempfile"
    include Utils

    attr_reader :file, :segments

    def initialize(file:)
      @file = file
      @segments = []
    end

    def <<(file)
      @segments << build_segment(file)
      remove_duplicates
      sort_segments
      @segments
    end

    def tempfile
      @tmp ||= Tempfile.new(File.basename(file))
      tmp.write([header, body].join("\n"))
      tmp.rewind
      tmp
    end

    def start_time
      segments.first.start_time
    end

    def end_time
      segments.last.end_time
    end

    def start_seconds(timestamp)
      return 0 if timestamp <= start_time

      timestamp - start_time
    end

    def end_seconds(timestamp)
      return segments.sum(&:duration) if timestamp >= end_time

      timestamp - start_time
    end

    private

    attr_reader :tmp

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

    def build_segment(file)
      return Segment.new(file:) if segments.empty?

      Segment.new(file:, start_time: segments.last.end_time)
    end
  end
end