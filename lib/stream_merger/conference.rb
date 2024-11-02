# frozen_string_literal: true

module StreamMerger
  # Conference
  class Conference
    MANIFEST_REGEX = /.+\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.\d{3}/

    def initialize
      @playlist_hash = {}
    end

    def playlists
      @playlist_hash.values.sort_by(&:start)
    end

    def update(files)
      files.each do |file|
        add_to_hash(file)
      end
    end

    def build_instructions
      timeline.map do |s, e|
        concurrent(s, e).map do |p|
          { file: p.file, start_seconds: p.start_seconds(s), end_seconds: p.end_seconds(e) }
        end
      end
    end

    private

    attr_reader :playlist_hash, :instructions

    def add_to_hash(file)
      filename = File.basename(file)
      if file.end_with?(".m3u8")
        @playlist_hash[filename] ||= Playlist.new(file:)
      elsif file.end_with?(".ts")
        @playlist_hash[manifest(file)] << file
      else
        raise ArgumentError, "Invalid HLS file: #{file}"
      end
    end

    def timeline
      playlists.map { |p| [p.start, p.end] }
               .flatten
               .sort
               .each_cons(2)
               .to_a
    end

    def concurrent(s, e)
      playlists.select { |p| p.start <= s && p.end >= e }
    end

    def manifest(file)
      "#{File.basename(file)[MANIFEST_REGEX]}.m3u8"
    end
  end
end
