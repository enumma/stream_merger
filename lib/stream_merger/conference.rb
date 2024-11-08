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
      @merged_files = []
      @local_files = []
      @conference_id = SecureRandom.hex
      @filelist = LocalFile.new("filelist_#{@conference_id}.txt")
    end

    def playlists
      @playlist_hash.values.sort_by(&:start_time)
    end

    def update(files)
      new_file_added = false
      files.each do |file|
        new_file_added = !add_to_hash(file).nil? || new_file_added
      end
      new_file_added
    end

    def build_instructions
      timeline.map do |start_time, end_time|
        concurrent(start_time, end_time).map do |playlist|
          build_instruction(playlist, start_time, end_time)
        end.compact
      end.reject(&:empty?)
    end

    def execute_instructions
      instruction_set = build_instructions
      instruction_set.each_with_index do |instructions, idx|
        next if @merged_instructions.include?(instructions)

        local_file = create_merged_file(idx, instructions)
        next if @merged_files.include?(local_file.path)

        @merged_instructions << instructions
        @merged_files << local_file.path
        @local_files << local_file
        filelist.write("file #{local_file.path}\n")
      end
    end

    def add_black_screen
      filelist.write("file #{File.expand_path("./lib/black_streams/1080x1920.mkv")}\n")
    end

    def purge!
      local_files.each(&:delete)
      filelist.delete
    end

    def create_mp4
      raise Error, "File does not exist" unless File.exist?(filelist.path)

      command = "ffmpeg -f concat -safe 0 -i '#{filelist.path}' -c copy ./lib/tmp/output_#{@conference_id}.mp4"
      process = IO.popen(command)
      Process.waitpid2(process.pid)
    end

    private

    attr_reader :playlist_hash, :instructions, :filelist, :local_files

    def add_to_hash(file)
      raise Error, "Invalid HLS file: #{file}" unless file.end_with?(".ts")

      @playlist_hash[manifest(file)] ||= Playlist.new(file_name: file_name(file))
      @playlist_hash[manifest(file)] << file
    end

    def timeline
      segments.map { |s| [s.start_time, s.end_time] }.flatten.uniq
              .flatten
              .sort
              .uniq
              .each_cons(2)
              .to_a
    end

    def segments
      playlists.map(&:segments).flatten
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

    def build_instruction(playlist, start_time, end_time)
      segment = playlist.segment(start_time, end_time)
      file = segment.mkv.path
      start_seconds = segment.seconds(start_time).round(3)
      end_seconds = segment.seconds(end_time).round(3)
      return if (end_seconds - start_seconds) < 0.2 # avoid corrupted files

      { file:, start_seconds:, end_seconds:,
        width: playlist.width,
        height: playlist.height }
    end

    def create_merged_file(idx, instructions)
      local_file = LocalFile.new("output_#{@conference_id}_#{idx}.mkv")
      merge_streams(instructions, local_file.path)
      local_file
    end
  end
end
