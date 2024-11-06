# frozen_string_literal: true

module StreamMerger
  # Playlist
  class Playlist
    require "tempfile"
    include Utils

    attr_reader :file_name, :file, :segments, :width, :height

    def initialize(file_name:)
      @file_name = file_name
      @segments = []
    end

    def <<(file)
      @segments << build_segment(file)
      remove_duplicates
      sort_segments
      set_resolution
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

    def header
      max_duration = segments.max { |s| s.duration }&.duration&.to_i # rubocop:disable Style/SymbolProc
      <<~HEADER.chomp
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:#{max_duration}
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:EVENT
        #EXT-X-DISCONTINUITY
      HEADER
    end

    def body
      str = segments.map do |segment|
        "#EXTINF:#{segment.duration},\n#{segment.file}"
      end.join("\n")
      "#{str}\n#EXT-X-ENDLIST"
    end

    def tempfile
      @tmp ||= Tempfile.new([file_name, ".m3u8"])
      tmp.write([header, body].join("\n"))
      tmp.rewind
      tmp
    end

    def set_resolution
      @file = tempfile.path
      return if @width && @height

      resolution = ffmpeg_resolution(file)
      @width = resolution[:width]
      @height = resolution[:height]
    end
  end
end
