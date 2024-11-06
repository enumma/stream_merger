# frozen_string_literal: true

module StreamMerger
  # Conference
  class Conference
    require "securerandom"
    include MergerUtils
    MANIFEST_REGEX = /.+\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.\d{3}/

    attr_reader :merged_instructions

    def initialize
      @playlist_hash = {}
      @merged_instructions = []
      @stream_name = SecureRandom.hex
      @stream_name = "aout"
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
          segment = p.segment(start_time, end_time)
          file = segment.file
          start_seconds = segment.seconds(start_time)
          end_seconds = segment.seconds(end_time)
          next if end_seconds < start_seconds

          { file:, start_seconds:, end_seconds:, width: p.width,
            height: p.height }
        end.compact
      end.reject(&:empty?)
    end

    def execute_instructions
      instruction_set = build_instructions
      instruction_set.each_with_index do |instructions, idx|
        next if @merged_instructions.include?(instructions)

        # output = "#{@stream_name}_#{idx}M.m3u8"

        output = "#{@stream_name}M.m3u8"
        merge_streams(instructions, output)
        @merged_instructions << instructions
      end
    end

    private

    attr_reader :playlist_hash, :instructions

    def add_to_hash(file)
      raise ArgumentError, "Invalid HLS file: #{file}" unless file.end_with?(".ts")

      @playlist_hash[manifest(file)] ||= Playlist.new(file_name: file_name(file))
      @playlist_hash[manifest(file)] << file
    end

    def timeline
      playlists.map { |p| p.segments.map { |s| [s.start_time, s.end_time] }.flatten.uniq }
               .flatten
               .sort
               .uniq
               .each_cons(2)
               .to_a
    end

    def concurrent(start_time, end_time)
      playlists.select { |p| p.start_time < end_time && p.end_time > start_time }
    end

    def file_name(file)
      File.basename(file)[MANIFEST_REGEX]
    end

    def manifest(file)
      "#{file_name(file)}.m3u8"
    end
  end
end
