# frozen_string_literal: true

module StreamMerger
  # MergedStream
  class MergedStream # rubocop:disable Metrics/ClassLength
    include Concat
    include Utils
    include MergerUtils
    include S3Utils

    attr_reader :file_uploader

    def initialize(conference)
      @conference = conference
      @stream_files = []
      file_name = file_name_with_timestamp("#{conference.conference_id}Merged")
      @main_m3u8 = StreamFile.new(file_name:, extension: ".m3u8")
      @concat_pls = StreamFile.new(file_name: "merged-concat#{SecureRandom.hex}", extension: ".txt", type: "fifo").path
      @file_uploader = FileUploader.new(main_m3u8: @main_m3u8)
      @social_stream = SocialStream.new(conference, handle: conference.handle, stream_keys: conference.stream_keys,
                                                    main_m3u8: @main_m3u8)
    end

    def execute(instructions)
      return false unless instructions.any?

      instructions.each do |instruction|
        stream_file = create_merged_file(file_instructions(instruction))
        concat_playlists([stream_file], finish: false)
        @stream_files << stream_file
      end

      true
    end

    def add_black_screen(finish: false)
      stream_file = StreamFile.new(file_name: "black_screen", extension: ".mkv")
      stream_file.write(File.open("./lib/black_streams/1080x1920.mkv").read, "wb")
      concat_playlists([stream_file], finish:)
    end

    def purge!
      kill_process(@ffmpeg_process)
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

    def kill_process(process)
      return unless process

      Process.kill(9, process.pid)
      puts "Process #{process.pid} killed successfully."
    rescue Errno::ESRCH
      puts "Process #{process.pid} does not exist."
    rescue Errno::EPERM
      puts "You do not have permission to kill process #{process.pid}."
    end

    private

    attr_reader :conference

    def ffmpeg_process
      return @ffmpeg_process if @ffmpeg_process

      cmd = (song_m3u8 ? ffmpeg_song_command : ffmpeg_command)

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

      @social_stream.start_social_processes
    end

    def ffmpeg_command
      <<-CMD
        ffmpeg -hide_banner -loglevel error -y -safe 0 -re -i #{@concat_pls} \
        -preset ultrafast -pix_fmt yuv420p -r 30 -g 30 -c:v libx264 -c:a aac -b:a 192k -ar 48000 -f hls \
        -hls_time 1 -hls_list_size 0 -hls_flags append_list \
        -vf setpts=PTS-STARTPTS \
        -af asetpts=PTS-STARTPTS \
        -hls_segment_filename "#{@main_m3u8.dirname}/#{@main_m3u8.file_name}_%09d.ts" \
        '#{@main_m3u8.path}'
      CMD
    end

    def ffmpeg_song_command
      <<-CMD
        ffmpeg -hide_banner -loglevel info -y -safe 0 -re -i #{@concat_pls} \
        -live_start_index 0 -re -max_reload 1000000 -m3u8_hold_counters 1000000 -i "#{song_m3u8}" \
        -filter_complex "[0:v]setpts=PTS-STARTPTS[main];
                         [1:v]format=yuv420p,colorkey=#0211F9:0.1:0.2[overlay];
                         [main][overlay]overlay=517:1639:eof_action=repeat[video];
                         [0:a]asetpts=PTS-STARTPTS[main_audio];
                         [1:a]asetpts=PTS-STARTPTS[song];
                         [main_audio][song]amix=inputs=2[audio]" \
        -map "[video]" -map "[audio]" \
        -preset ultrafast -pix_fmt yuv420p -r 30 -g 30 -c:v libx264 -c:a aac -b:a 192k -ar 48000 -f hls \
        -hls_time 1 -hls_list_size 0 -hls_flags append_list \
        -hls_segment_filename "#{@main_m3u8.dirname}/#{@main_m3u8.file_name}_%09d.ts" \
        '#{@main_m3u8.path}'
      CMD
    end

    def song_m3u8
      @song_m3u8 ||= streams_bucket.objects(prefix: "streams/song#{conference.conference_id}").select do |s|
        s.key.match?(/\.m3u8/)
      end.first&.public_url
    end
  end
end
