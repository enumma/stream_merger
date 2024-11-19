# frozen_string_literal: true

module StreamMerger
  class SocialStreamer
    include Concat
    COMMON_RESOLUTION = "1080x1920" # Define the common resolution for scaling
    IO_FONTSIZE = 44 # Intro and outro fontsize
    W_FONTSIZE = 32 # Watermark fontsize
    RETRY_LIMIT = 60

    def initialize(stream_key: nil, handle: nil)
      stream_key = "7dy2-gsj2-m7rk-8j0a-7vxk"
      handle = "mauricio"
      @handle = "@#{handle}" if handle
      @stream_key = stream_key
      @concat_pls = StreamFile.new(file_name: "social-concat", extension: ".txt", type: "fifo").path
      @final = StreamFile.new(file_name: "social-final", extension: ".m3u8").path
    end

    def concat_file(files, finish: false)
      return if @handle.nil? || @stream_key.nil?

      fn_concat_feed(files, finish:)
      stream_process
    end

    private

    attr_accessor :handle, :stream_key

    def ffmpeg_process
      @ffmpeg_process ||= IO.popen(hls_command, "w")
    end

    def stream_process
      return @stream_process if @stream_process

      sleep 5
      @stream_process = IO.popen(stream_command, "w")
    end

    # def hls_command
    #   <<~CMD
    #     ffmpeg -hide_banner -loglevel debug \
    #     -i "#{intro_file}" -safe 0 -i "#{@concat_pls}" -i "#{outro_file}" -i "#{watermark_file}" \
    #     -filter_complex "#{filter_complex}" \
    #     -map "[outv_final]" -map "[outa]" -flags +global_header -c:v libx264 \
    #     -preset ultrafast -r 30 -g 30 -c:a aac \
    #     -f hls -hls_time 1 \
    #     -hls_playlist_type event \
    #     -hls_flags delete_segments+append_list \
    #     -master_pl_name master.m3u8 \
    #     -method PUT \
    #     -http_persistent 1 \
    #     "https://a.upload.youtube.com/http_upload_hls?cid=#{stream_key}&copy=0&file=master.m3u8"
    #   CMD
    # end

    def stream_command
      <<~CMD
        ffmpeg -hide_banner -loglevel debug \
        -re -live_start_index 0 -i "#{@final}" \
        -preset ultrafast -r 30 -g 30 -c:a aac \
        -f hls -hls_time 1 \
        -hls_playlist_type event \
        -hls_flags delete_segments+append_list \
        -master_pl_name master.m3u8 \
        -method PUT \
        -http_persistent 1 \
        "https://a.upload.youtube.com/http_upload_hls?cid=#{stream_key}&copy=0&file=master.m3u8"
      CMD
    end

    def hls_command
      <<~CMD
        ffmpeg -hide_banner -loglevel error \
        -i "#{intro_file}" -safe 0 -i "#{@concat_pls}" -i "#{outro_file}" -i "#{watermark_file}" \
        -filter_complex "#{filter_complex}" \
        -map "[outv_final]" -map "[outa]" -flags +global_header -c:v libx264 \
        -preset ultrafast -r 30 -g 30 -c:a aac \
        -f hls -hls_time 1 \
        -hls_playlist_type event \
        -hls_flags append_list \
        #{@final}
      CMD
    end

    # def hls_command
    #   <<~CMD
    #     ffmpeg -hide_banner -loglevel error \
    #     -i "#{intro_file}" -safe 0 -i "#{@concat_pls}" -i "#{outro_file}" -i "#{watermark_file}" \
    #     -filter_complex "#{filter_complex}" \
    #     -map "[outv_final]" -map "[outa]" -flags +global_header -c:v libx264 \
    #     -preset ultrafast -r 30 -g 30 -c:a aac \
    #     all.mkv
    #   CMD
    # end

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
      "./lib/social_stream/intro.mkv"
    end

    def outro_file
      "./lib/social_stream/outro.mkv"
    end

    def watermark_file
      "./lib/social_stream/watermark.png"
    end

    def intro_outro_font_file
      "./lib/social_stream/Ubuntu-Medium.ttf"
    end

    def watermark_font_file
      "./lib/social_stream/Lato-Regular.ttf"
    end
  end
end
