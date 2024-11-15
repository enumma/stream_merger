# frozen_string_literal: true

module StreamMerger
  # Conference
  class Conference
    include MergerUtils
    include Concat
    MANIFEST_REGEX = /.+\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.\d{3}/

    attr_reader :control_time

    def initialize(main_m3u8:, conference_id: SecureRandom.hex)
      @playlist_hash = {}
      @merged_instructions = []
      @stream_files = []
      @concat_pls = StreamFile.new(file_name: "concat", extension: ".txt", type: "fifo").path
      @conference_id = conference_id
      @main_m3u8 = main_m3u8
    end

    def playlists
      @playlist_hash.values.sort_by(&:start_time)
    end

    def update(files)
      threads = files.map do |file, last_modified|
        Thread.new do
          add_to_hash(file, last_modified)
        end
      end

      # Wait for all threads to finish
      threads.each(&:join)
      playlists.each(&:reorder)
    end

    def execute(pop: true)
      instructions = build_instructions(pop:)
      executed = false
      instructions.each do |instruction|
        executed = execute_instruction(instruction)
      end
      executed
    end

    def build_instructions(pop:)
      complete_set = timeline.map do |start_time, end_time|
        concurrent(start_time, end_time).map do |playlist|
          build_instruction(playlist, start_time, end_time)
        end.compact
      end.reject(&:empty?)

      popped_set = complete_set.dup
      4.times { popped_set.pop } if pop
      popped_set
    end

    def execute_instruction(instruction)
      return false if @merged_instructions.include?(instruction)

      @control_time = Time.now
      @merged_instructions << instruction
      stream_file = create_merged_file(instruction)
      @stream_files << stream_file
      fn_concat_feed(stream_file.path)
      true
    end

    def add_black_screen
      stream_file = StreamFile.new(file_name: "black_screen", extension: ".mkv")
      stream_file.write(File.open("./lib/black_streams/1080x1920.mkv").read, "wb")
      fn_concat_feed(stream_file.path)
    end

    def purge!
      stream_files.each(&:delete)
      File.delete(@concat_pls) if File.exist?(@concat_pls)
      stop_ffmpeg_process
    end

    def segments
      playlists.map(&:segments).flatten
    end

    private

    attr_reader :merged_instructions, :playlist_hash, :instructions, :stream_files

    def add_to_hash(file, last_modified)
      raise Error, "Invalid HLS file: #{file}" unless file.end_with?(".ts")

      @playlist_hash[manifest(file)] ||= Playlist.new(file_name: file_name(file))
      @playlist_hash[manifest(file)].add_segment(file, last_modified)
    end

    def timeline
      segments
        .map { |s| [s.start_time, s.end_time] }
        .flatten
        .uniq
        .sort
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

    def build_instruction(playlist, start_time, end_time)
      segment = playlist.segment(start_time, end_time)

      file = segment.mkv.path
      start_seconds = segment.seconds(start_time)
      end_seconds = segment.seconds(end_time)

      return if start_seconds.negative? || (end_seconds - start_seconds) < 0.2 # avoid corrupted files

      { file:, start_seconds:, end_seconds:,
        width: playlist.width,
        height: playlist.height }
    end

    def create_merged_file(instructions)
      stream_file = StreamFile.new(file_name: "output", extension: ".mkv")
      merge_streams(instructions, stream_file.path)
      stream_file
    end
  end
end
