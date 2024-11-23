# frozen_string_literal: true

module StreamMerger
  # Conference
  class Conference
    MANIFEST_REGEX = /.+\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.\d{3}/

    attr_reader :handle, :stream_keys, :control_time, :conference_id, :playlist_hash

    def initialize(stream_keys: [], handle: nil, conference_id: SecureRandom.hex)
      @handle = handle
      @stream_keys = stream_keys
      @playlist_hash = {}
      @merged_instructions = []
      @conference_id = conference_id
      @merged_stream = MergedStream.new(self)
    end

    def social?
      !handle.nil? && stream_keys.any?
    end

    def playlists
      @playlist_hash.values
    end

    def update(files)
      threads = files.map do |file, last_modified|
        Thread.new { add_to_hash(file, last_modified) }
      end

      # Wait for all threads to finish
      threads.each(&:join)
      playlists.each(&:reorder)
    end

    def execute(pop: true)
      new_instructions = []
      build_instructions(pop:).each do |instruction|
        next if @merged_instructions.include?(instruction)

        @control_time = Time.now
        @merged_instructions << instruction
        new_instructions << instruction
      end
      @merged_stream.execute(new_instructions)
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

    def add_black_screen(finish: false)
      @merged_stream.add_black_screen(finish:)
    end

    def upload_files
      @merged_stream.upload_files
    end

    def purge!
      @merged_stream.purge!
    end

    def segments
      playlists.map(&:segments).flatten
    end

    def wait_to_finish
      @merged_stream.wait_to_finish
    end

    private

    attr_reader :merged_instructions

    def add_to_hash(file, last_modified)
      raise Error, "Invalid HLS file: #{file}" unless file.end_with?(".ts") || file.match("\.ts\?")

      @playlist_hash[manifest(file)] ||= Playlist.new(file_name: file_name(file))
      @playlist_hash[manifest(file)].add_segment(file:, last_modified:)
    end

    def file_name(file)
      File.basename(file)[MANIFEST_REGEX]
    end

    def manifest(file)
      "#{file_name(file)}.m3u8"
    end

    def timeline
      segments
        .map { |s| [s.start_time, s.end_time] }
        .flatten.uniq.sort.each_cons(2).to_a
    end

    def concurrent(start_time, end_time)
      playlists.sort_by(&:start_time).select { |p| p.start_time < end_time && p.end_time > start_time }
    end

    def build_instruction(playlist, start_time, end_time)
      segment = playlist.segment(start_time, end_time)
      start_seconds = segment.seconds(start_time).round(4)
      end_seconds = segment.seconds(end_time).round(4)

      return if start_seconds.negative? || (end_seconds - start_seconds) < 0.2 # avoid corrupted files

      { start_seconds:, end_seconds:,
        manifest: manifest(segment.file),
        segment_id: segment.segment_id,
        width: playlist.width,
        height: playlist.height }
    end
  end
end
