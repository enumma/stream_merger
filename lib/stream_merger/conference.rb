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
      @stream_files = []
      @conference_id = SecureRandom.hex
      @concat_pls = StreamFile.new(file_name: "concat", extension: ".txt", type: "fifo").path
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

        stream_file = create_merged_file(idx, instructions)
        next if @merged_files.include?(stream_file.path)

        @merged_instructions << instructions
        @merged_files << stream_file.path
        @stream_files << stream_file
        fn_concat_feed(stream_file.path)
      end
    end

    def add_black_screen
      stream_file = StreamFile.new(file_name: "black_screen", extension: ".mkv")
      stream_file.write(File.open("./lib/black_streams/1080x1920.mkv").read, "wb")
      fn_concat_feed(stream_file.path)
    end

    def purge!
      sleep 5
      stream_files.each(&:delete)
      File.delete(@concat_pls) if File.exist?(@concat_pls)
      Process.kill("TERM", @ffmpeg_process.pid) if @ffmpeg_process&.pid
    end

    private

    attr_reader :playlist_hash, :instructions, :stream_files

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
      stream_file = StreamFile.new(file_name: "output_#{@conference_id}_#{idx}", extension: ".mkv")
      merge_streams(instructions, stream_file.path)
      stream_file
    end

    def fn_concat_feed(file)
      # @ffmpeg_process ||= IO.popen("ffmpeg -y -safe 0 -i #{@concat_pls} -preset ultrafast -pix_fmt yuv420p -r 30 -c:v libx264 -c:a aac all.mkv",
      #                              "w")
      @ffmpeg_process ||= IO.popen(
        "ffmpeg -y -safe 0 -i #{@concat_pls} -preset ultrafast -pix_fmt yuv420p -r 30 -c:v libx264 -c:a aac -f hls -hls_time 10 -hls_list_size 0 -hls_segment_filename 'segment_%03d.ts' all.m3u8", "w"
      )

      # Write the required information to the FIFO
      File.open(@concat_pls, "w") do |fifo|
        fifo.puts "ffconcat version 1.0\nfile '#{file}'\nfile '#{@concat_pls}'\noption safe 0"
      end
    end
  end
end
