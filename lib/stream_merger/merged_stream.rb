# frozen_string_literal: true

module StreamMerger
  # MergedStream
  class MergedStream
    include Concat
    include Utils
    include MergerUtils

    attr_reader :file_uploader

    def initialize(conference)
      @conference = conference
      @stream_files = []
      file_name = file_name_with_timestamp("#{conference.conference_id}Merged")
      @main_m3u8 = StreamFile.new(file_name:, extension: ".m3u8")
      @concat_pls = StreamFile.new(file_name: "merged-concat#{SecureRandom.hex}", extension: ".txt", type: "fifo").path
      @file_uploader = FileUploader.new(main_m3u8: @main_m3u8)
      @social_stream = SocialStream.new(conference, handle: conference.handle, stream_keys: conference.stream_keys)
    end

    def execute(instructions)
      stream_files = instructions.map do |instruction|
        create_merged_file(file_instructions(instruction))
      end.compact
      return false unless stream_files.any?

      concat_playlists(stream_files, finish: false)
      @stream_files += stream_files
      true
    end

    def add_black_screen(finish: false)
      stream_file = StreamFile.new(file_name: "black_screen", extension: ".mkv")
      stream_file.write(File.open("./lib/black_streams/1080x1920.mkv").read, "wb")
      concat_playlists([stream_file], finish:)
    end

    def purge!
      kill_process
      @stream_files.each(&:delete) # Delete temp aux files
      File.delete(@concat_pls) if File.exist?(@concat_pls) # Delete concatenation list
      @file_uploader.delete_files # Delete m3u8 and segments
      @social_stream.purge! # Purge social stream
    end

    def upload_files
      return false unless @file_uploader.more_files_to_upload?

      @file_uploader.upload_files_in_batches
      true
    end

    def wait_to_finish
      Process.wait(ffmpeg_process.pid)
      @social_stream.wait_to_finish if conference.social?
    end

    def kill_process
      return unless ffmpeg_process

      Process.kill(9, ffmpeg_process.pid)
      puts "Process #{ffmpeg_process.pid} killed successfully."
    rescue Errno::ESRCH
      puts "Process #{ffmpeg_process.pid} does not exist."
    rescue Errno::EPERM
      puts "You do not have permission to kill process #{ffmpeg_process.pid}."
    end

    private

    attr_reader :conference

    def ffmpeg_process
      return @ffmpeg_process if @ffmpeg_process

      cmd = <<-CMD
        ffmpeg -hide_banner -loglevel error -y -safe 0 -i #{@concat_pls} \
        -preset ultrafast -pix_fmt yuv420p -r 30 -g 30 -c:v libx264 -c:a aac -b:a 192k -ar 48000 -f hls \
        -hls_time 1 -hls_list_size 0 -hls_flags append_list \
        -hls_segment_filename "#{@main_m3u8.dirname}/#{@main_m3u8.file_name}_%09d.ts" \
        '#{@main_m3u8.path}'
      CMD

      @ffmpeg_process = IO.popen(cmd, "w")
    end

    def file_instructions(instruction)
      instruction.map do |i|
        playlist = conference.playlist_hash[i[:manifest]]
        segment = playlist.segments.find { |s| s.segment_id == i[:segment_id] }
        i.merge(file: segment.mkv.path)
      end
    end

    def create_merged_file(instructions)
      stream_file = StreamFile.new(file_name: "merged-output", extension: ".mkv")
      merge_streams(instructions, stream_file.path)
      stream_file
    end

    def concat_playlists(stream_files, finish: false)
      concat_feed(stream_files, finish:)
      return unless conference.social?

      @social_stream.concat_social(stream_files, finish:)
    end
  end
end
