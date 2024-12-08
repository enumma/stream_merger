# frozen_string_literal: true

module StreamMerger
  # SingleStream
  class SingleStream # rubocop:disable Metrics/ClassLength
    include Utils
    include S3Utils

    COMMON_RESOLUTION = "1080x1920" # Define the common resolution for scaling
    IO_FONTSIZE = 44 # Intro and outro fontsize
    W_FONTSIZE = 32 # Watermark fontsize

    def initialize(conference_id:, stream_id:, handle:, stream_keys:)
      file_name = file_name_with_timestamp("#{conference_id}Merged")
      @conference_id = conference_id
      @handle = handle
      @stream_keys = stream_keys
      @stream_id = stream_id
      @out_m3u8 = StreamFile.new(file_name:, extension: ".m3u8")
      @file_uploader = FileUploader.new(main_m3u8: @out_m3u8)
    end

    def start
      ffmpeg_process
      return unless stream_keys.any?

      load_out_m3u8
      start_social_processes
    end

    def wait_to_finish
      Process.wait(@ffmpeg_process.pid) if @ffmpeg_process
      Process.wait(@youtube_process.pid) if @youtube_process

      kill_process(@ffmpeg_process)
      kill_process(@youtube_process)
    end

    def upload_files
      return false unless @file_uploader.more_files_to_upload?

      @file_uploader.upload_files_in_batches
      true
    end

    private

    attr_reader :conference_id, :handle, :out_m3u8, :stream_keys, :stream_id

    def ffmpeg_process
      return @ffmpeg_process if @ffmpeg_process

      cmd = ffmpeg_command

      @ffmpeg_process = IO.popen(cmd, "w")
    end

    def load_out_m3u8
      i = 0
      loop do
        break if File.size(out_m3u8.path).positive? || i >= 60

        puts "#{out_m3u8.path} does not exist yet!"
        i += 1
        sleep 10
      end
    end

    def start_social_processes
      stream_keys.each do |type, stream_key|
        case type
        when "YoutubeStream"
          cmd = youtube_command(stream_key)
          @youtube_process ||= IO.popen(cmd, "w")
        end
      end
    end

    def ffmpeg_command
      <<-CMD
        ffmpeg -hide_banner -loglevel info -y \
        -live_start_index 0 -max_reload 1000000 -m3u8_hold_counters 1000000 -i "#{participant_m3u8}" \
        -live_start_index 0 -max_reload 1000000 -m3u8_hold_counters 1000000 -i "#{song_m3u8}" \
        -filter_complex "[0:v]hflip,setpts=PTS-STARTPTS[main];
                         [1:v]format=yuv420p,colorkey=#0211F9:0.1:0.2[overlay];
                         [main][overlay]overlay=517:1639:eof_action=repeat[video];
                         [0:a]asetpts=PTS-STARTPTS[main_audio];
                         [1:a]asetpts=PTS-STARTPTS[song];
                         [main_audio][song]amix=inputs=2[audio]" \
        -map "[video]" -map "[audio]" \
        -preset ultrafast -pix_fmt yuv420p -r 30 -g 30 -c:v libx264 -c:a aac -b:a 192k -ar 48000 -f hls \
        -hls_time 2 -hls_list_size 0 -hls_flags append_list \
        -hls_segment_filename "#{out_m3u8.dirname}/#{out_m3u8.file_name}_%09d.ts" \
        '#{out_m3u8.path}'
      CMD
    end

    def watermark_font_file
      File.expand_path("./lib/social_stream/Lato-Regular.ttf")
    end

    def watermark_file
      File.expand_path("./lib/social_stream/watermark.png")
    end

    def intro_outro_font_file
      File.expand_path("./lib/social_stream/Ubuntu-Medium.ttf")
    end

    def intro_file
      input = File.open("./lib/social_stream/intro.mkv")
      input.path
    end

    def outro_file
      input = File.open("./lib/social_stream/outro.mkv")
      input.path
    end

    def base_social_command
      <<-CMD
        ffmpeg -hide_banner -loglevel verbose -y \
        -i "#{intro_file}" \
        -live_start_index 0 -re -max_reload 1000000 -m3u8_hold_counters 1000000 -i "#{out_m3u8.path}" \
        -i "#{outro_file}" \
        -i "#{watermark_file}" \
        -live_start_index 0 -max_reload 1000000 -m3u8_hold_counters 1000000 -i "#{song_m3u8}" \
        -filter_complex "#{filter_complex}" \
        -map "[outv_final]" -map "[outa]" -flags +global_header -c:v libx264 \
        -tune zerolatency -preset ultrafast \
        -max_delay 500000 -bufsize 16000k \
        -c:a aac -b:a 192k -ar 48000 \
        -hls_time 2 -hls_list_size 0 -r 30 -g 30
      CMD
    end

    def youtube_command(stream_key)
      cmd = <<-CMD
        -http_persistent 1 -method POST \
        'https://a.upload.youtube.com/http_upload_hls?cid=#{stream_key}&copy=0&file=master.m3u8'
      CMD
      "#{base_social_command.strip} #{cmd}"
    end

    def filter_complex
      <<~FILTER
        [0:v]scale=#{COMMON_RESOLUTION}[intro];
        [intro]drawtext=fontfile=#{intro_outro_font_file}:text='#{handle}':fontsize=#{IO_FONTSIZE}:fontcolor=#1E1E1E:x=(w-text_w)/2:y=(h-text_h)/2+223:alpha='if(gte(t,1.3),min(1,(t-1.3)/1.3),0)'[overlayed_intro];
        [1:v]null[main];
        [main][3:v]overlay=(main_w - overlay_w - 24):(main_h - overlay_h - 376)[main_with_image];
        [main_with_image]drawtext=fontfile=#{watermark_font_file}:text='#{handle}':fontsize=#{W_FONTSIZE}:fontcolor=#FFFFFF:x=w - text_w - 24:y=h - text_h - 318[overlayed_main];
        [2:v]scale=#{COMMON_RESOLUTION}[outro];
        [outro]drawtext=fontfile=#{intro_outro_font_file}:text='#{handle}':fontsize=#{IO_FONTSIZE}:fontcolor=#1E1E1E:x=(w-text_w)/2:y=(h-text_h)/2+223:alpha='if(gte(t,1.3),min(1,(t-1.3)/1.3),0)'[overlayed_outro];
        [overlayed_intro][0:a][overlayed_main][1:a][overlayed_outro][2:a]concat=n=3:v=1:a=1[outv][outa]; \
        [outv]format=yuv420p[outv_final]
      FILTER
    end

    def song_m3u8 # rubocop:disable Metrics/MethodLength
      return @song_m3u8 if @song_m3u8

      i = 0
      loop do
        @song_m3u8 = streams_bucket.objects(prefix: "streams/song#{conference_id}").select do |s|
          s.key.match?(/\.m3u8/)
        end.first&.public_url
        break if @song_m3u8 || i >= 600

        i += 1
        sleep 1
      end
      @song_m3u8
    end

    def participant_m3u8 # rubocop:disable Metrics/MethodLength
      return @participant_m3u8 if @participant_m3u8

      i = 0
      loop do
        @participant_m3u8 = videos_bucket.objects(prefix: "streams/#{stream_id}").select do |s|
          s.key.match?(/\.m3u8/)
        end.first&.public_url
        break if @participant_m3u8 || i >= 600

        i += 1
        sleep 1
      end
      @participant_m3u8
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
  end
end
