# frozen_string_literal: false

module StreamMerger
  # SocialStream
  class SocialStream
    include Concat
    include MergerUtils
    include Utils
    include S3Utils

    COMMON_RESOLUTION = "1080x1920".freeze # Define the common resolution for scaling
    IO_FONTSIZE = 44 # Intro and outro fontsize
    W_FONTSIZE = 32 # Watermark fontsize

    def initialize(conference, handle:, stream_keys:)
      @conference = conference
      @handle = handle
      @stream_keys = stream_keys
    end

    def start_social_processes
      @stream_keys.each do |type, stream_key|
        case type
        when "YoutubeStream"
          cmd = youtube_command(stream_key)
          @youtube_process ||= IO.popen(cmd, "w")
        end
      end
    end

    def wait_to_finish
      Process.wait(@youtube_process.pid) if @youtube_process
    end

    def purge!
      kill_process(@youtube_process)
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

    attr_reader :conference, :handle

    def watermark_font_file
      File.expand_path("./lib/social_stream/Lato-Regular.ttf")
    end

    def watermark_file
      File.expand_path("./lib/social_stream/watermark.png")
    end

    def intro_outro_font_file
      File.expand_path("./lib/social_stream/Ubuntu-Medium.ttf")
    end

    def ffmpeg_process
      return @ffmpeg_process if @ffmpeg_process

      cmd = (song_m3u8 ? ffmpeg_song_command : ffmpeg_command)

      @ffmpeg_process = IO.popen(cmd, "w")
    end

    def intro_file
      input = File.open("./lib/social_stream/intro.mkv")
      input.path
    end

    def outro_file
      input = File.open("./lib/social_stream/outro.mkv")
      input.path
    end

    def youtube_command(stream_key)
      cmd = <<-CMD
        -http_persistent 1 -method POST \
        'https://a.upload.youtube.com/http_upload_hls?cid=#{stream_key}&copy=0&file=master.m3u8'
      CMD
      "#{base_social_command.strip} #{cmd}"
    end

    def base_social_command
      <<-CMD
        sleep 15
        ffmpeg -hide_banner -loglevel verbose -y \
        -i "#{intro_file}" \
        -live_start_index 0 -re -max_reload 1000000 -m3u8_hold_counters 1000000 -i "#{main_m3u8}" \
        -i "#{outro_file}" \
        -i "#{watermark_file}" \
        -filter_complex "#{filter_complex}" \
        -map "[outv_final]" -map "[outa]" -flags +global_header -c:v libx264 \
        -tune zerolatency -preset ultrafast \
        -max_delay 500000 -bufsize 16000k \
        -c:a aac -b:a 192k -ar 48000 \
        -hls_time 2 -hls_list_size 0 -r 30 -g 30
      CMD
    end

    def filter_complex
      <<~FILTER
        [0:v]scale=#{COMMON_RESOLUTION}[intro];
        [intro]drawtext=fontfile=#{intro_outro_font_file}:text='#{handle}':fontsize=#{IO_FONTSIZE}:fontcolor=#1E1E1E:x=(w-text_w)/2:y=(h-text_h)/2+223:alpha='if(gte(t,1.3),min(1,(t-1.3)/1.3),0)'[overlayed_intro];
        [1:v]scale=#{COMMON_RESOLUTION}[main];
        [main][3:v]overlay=(main_w - overlay_w - 24):(main_h - overlay_h - 376)[main_with_image];
        [main_with_image]drawtext=fontfile=#{watermark_font_file}:text='#{handle}':fontsize=#{W_FONTSIZE}:fontcolor=#FFFFFF:x=w - text_w - 24:y=h - text_h - 318[overlayed_main];
        [2:v]scale=#{COMMON_RESOLUTION}[outro];
        [outro]drawtext=fontfile=#{intro_outro_font_file}:text='#{handle}':fontsize=#{IO_FONTSIZE}:fontcolor=#1E1E1E:x=(w-text_w)/2:y=(h-text_h)/2+223:alpha='if(gte(t,1.3),min(1,(t-1.3)/1.3),0)'[overlayed_outro];
        [overlayed_intro][0:a][overlayed_main][1:a][overlayed_outro][2:a]concat=n=3:v=1:a=1[outv][outa]; \
        [outv]format=yuv420p[outv_final]
      FILTER
    end

    def main_m3u8 # rubocop:disable Metrics/MethodLength
      return @main_m3u8 if @main_m3u8

      i = 0
      loop do
        @main_m3u8 = videos_bucket.objects(prefix: "streams/#{conference.conference_id}").select do |s|
          s.key.match?(/\.m3u8/)
        end.first&.public_url
        break if @main_m3u8 || i >= 30

        i += 1
        sleep 1
      end
      @main_m3u8
    end
  end
end
