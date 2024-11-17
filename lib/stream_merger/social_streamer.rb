# frozen_string_literal: true

module StreamMerger
  # SocialStreamer
  class SocialStreamer
    COMMON_RESOLUTION = "1080x1920" # Define the common resolution for scaling
    IO_FONTSIZE = 44 # Intro and outro fontsize
    W_FONTSIZE = 32 # Watermark fontsize
    RETRY_LIMIT = 60

    def initialize(handle:, main_m3u8:)
      @handle = "@#{handle}"
      @main_m3u8 = main_m3u8.path
      @stream_key = "jxqh-rzah-e3dz-jj0h-d60f"
    end

    def start_stream
      puts "Starting combined stream (intro + main + outro)..."

      run_ffmpeg(hls_command)
    end

    private

    attr_accessor :handle, :main_m3u8, :stream_id, :stream_key

    def hls_command
      <<~CMD
        ffmpeg -hide_banner -loglevel error \
        -i "#{intro_file}" -live_start_index 0 -i "#{main_m3u8}" -i "#{outro_file}" -i "#{watermark_file}" \
        -filter_complex "#{filter_complex}" \
        -map "[outv_final]" -map "[outa]" -flags +global_header -c:v libx264 \
        -preset veryfast -max_delay 2000000 -b:v 8000k -bufsize 64000k -r 30 -g 120 \
        -c:a aac -b:a 128k -ar 44100 \
        -f hls -hls_time 4 \
        -hls_playlist_type event \
        -hls_flags delete_segments+append_list \
        -master_pl_name master.m3u8 \
        -method PUT \
        -http_persistent 1 \
        "https://a.upload.youtube.com/http_upload_hls?cid=#{stream_key}&copy=0&file=master.m3u8"
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

    def intro_file
      File.open("./lib/social_stream/intro.mp4").path
    end

    def outro_file
      File.open("./lib/social_stream/outro.mp4").path
    end

    def watermark_file
      File.open("./lib/social_stream/watermark.png").path
    end

    def intro_outro_font_file
      File.open("./lib/social_stream/Ubuntu-Medium.ttf").path
    end

    def watermark_font_file
      File.open("./lib/social_stream/Lato-Regular.ttf").path
    end

    def run_ffmpeg(command)
      puts "Executing FFmpeg command: #{command}"

      # Start the FFmpeg process
      process = IO.popen(command)

      # Wait for the process to finish and capture its exit status
      _pid, status = Process.waitpid2(process.pid)

      if status.success?
        puts "FFmpeg completed successfully."
      else
        puts "FFmpeg failed with exit status: #{status.exitstatus}"
      end
    end
  end
end
