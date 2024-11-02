# frozen_string_literal: true

module StreamMerger
  # Conference
  class Conference
    def initialize
      @playlist_hash = {}
    end

    def playlists
      @playlist_hash.values
    end

    def update(files)
      files.each do |file|
        add_to_hash(file)
      end
    end

    private

    attr_reader :playlist_hash

    def add_to_hash(file)
      filename = File.basename(file)
      if file.end_with?(".m3u8")
        @playlist_hash[filename] ||= Playlist.new(file:)
      elsif file.end_with?(".ts")
        segment = Segment.new(file:)
        @playlist_hash[segment.manifest] << segment
      else
        raise ArgumentError, "Invalid HLS file: #{file}"
      end
    end
  end
end
