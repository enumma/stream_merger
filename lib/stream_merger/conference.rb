# frozen_string_literal: true

module StreamMerger
  # Conference
  class Conference
    require "securerandom"
    include MergerUtils
    MANIFEST_REGEX = /.+\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.\d{3}/

    def initialize
      @playlist_hash = {}
      @black_file = "./black_screen_stream/black.m3u8"
    end

    def playlists
      @playlist_hash.values.sort_by(&:start_time)
    end

    def update(files)
      files.each do |file|
        add_to_hash(file)
      end
    end

    def build_instructions
      timeline.map do |start_time, end_time|
        concurrent(start_time, end_time).map do |p|
          { file: p.file, start_seconds: p.start_seconds(start_time), end_seconds: p.end_seconds(end_time),
            width: p.width, height: p.height }
        end
      end
    end

    def execute_instructions
      stream_name = SecureRandom.hex
      instruction_set = build_instructions
      instruction_set.each_with_index do |instructions, idx|
        merge_streams(instructions, "#{stream_name}_#{idx}.m3u8")
      end
    end

    private

    attr_reader :playlist_hash, :instructions

    def add_to_hash(file)
      raise ArgumentError, "Invalid HLS file: #{file}" unless file.end_with?(".ts")

      @playlist_hash[manifest(file)] ||= Playlist.new(file_name: File.basename(file)[MANIFEST_REGEX])
      @playlist_hash[manifest(file)] << file
    end

    def timeline
      playlists.map { |p| [p.start_time, p.end_time] }
               .flatten
               .sort
               .each_cons(2)
               .to_a
    end

    def concurrent(start_time, end_time)
      playlists.select { |p| p.start_time <= start_time && p.end_time >= end_time }
    end

    def manifest(file)
      "#{File.basename(file)[MANIFEST_REGEX]}.m3u8"
    end
  end
end
