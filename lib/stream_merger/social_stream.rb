# frozen_string_literal: true

module StreamMerger
  # SocialStream
  class SocialStream # rubocop:disable Metrics/ClassLength
    include Concat
    include MergerUtils
    include Utils

    COMMON_RESOLUTION = "1080x1920" # Define the common resolution for scaling
    IO_FONTSIZE = 44 # Intro and outro fontsize
    W_FONTSIZE = 32 # Watermark fontsize

    def initialize(conference, handle:, stream_key:)
      @handle = handle
      @stream_key = stream_key
      file_name = file_name_with_timestamp("#{conference.conference_id}Social")
      @main_m3u8 = StreamMerger::StreamFile.new(file_name:, extension: ".m3u8")
      @concat_pls = StreamFile.new(file_name: "social-concat", extension: ".txt", type: "fifo").path
      @add_intro = true
    end

    def concat_social(stream_files, finish:) # rubocop:disable Metrics/MethodLength
      files = stream_files.map do |input|
        output = StreamMerger::StreamFile.new(file_name: "social-output", extension: ".mkv")
        watermark_command(input, output)
        output
      end
      add_intro if @add_intro
      if finish
        add_outro
      else
        concat_feed(files, finish:)
      end
      youtube_process
    end

    def youtube_process
      return @youtube_process if @youtube_process

      cmd = <<-CMD
        ffmpeg -hide_banner -loglevel error -y \
        -re -i "#{@main_m3u8.path}" -preset ultrafast -r 30 -g 30 -c:a aac \
        -f hls -hls_time 1 -hls_playlist_type event -hls_flags delete_segments+append_list \
        -master_pl_name master.m3u8 \
        -method PUT -http_persistent 1 \
        "https://a.upload.youtube.com/http_upload_hls?cid=#{@stream_key}&copy=0&file=master.m3u8"
      CMD

      @youtube_process = IO.popen(cmd, "w")
    end

    def wait_to_finish
      Process.wait(ffmpeg_process.pid)
      Process.wait(youtube_process.pid)
    end

    private

    attr_reader :handle

    def watermark_command(input, output)
      `ffmpeg -hide_banner -loglevel error -y \
       -i "#{input.path}" -i "#{watermark_file}" \
       -filter_complex "#{watermark_filter_complex}" \
       -map "[outv_final]" -map 0:a \
       -c:v libx264 -crf 23 -preset ultrafast \
       -c:a aac -b:a 192k -ar 48000 "#{output.path}"`
    end

    def watermark_filter_complex
      <<~FILTER
        [0:v]scale=#{COMMON_RESOLUTION}[main];
        [main][1:v]overlay=W-w-24:H-h-376[main_with_image];
        [main_with_image]drawtext=fontfile=#{watermark_font_file}:text='#{handle}':fontsize=#{W_FONTSIZE}:fontcolor=white:x=w-text_w-24:y=h-text_h-318[outv_final]
      FILTER
    end

    def intro_outro_command(input, output)
      `ffmpeg -hide_banner -loglevel error -y \
        -i "#{input.path}" \
        -filter_complex "#{intro_outro_filter_complex}" \
        -map "[outv_final]" -map 0:a \
        -c:v libx264 -crf 23 -preset ultrafast \
        -c:a aac "#{output.path}"`
    end

    def intro_outro_filter_complex
      <<~FILTER
        [0:v]scale=#{COMMON_RESOLUTION}[main];
        [main]drawtext=fontfile=#{intro_outro_font_file}:text='#{handle}':fontsize=#{IO_FONTSIZE}:fontcolor=#1E1E1E:x=(w-text_w)/2:y=(h-text_h)/2+223:alpha='if(gte(t,1.3),min(1,(t-1.3)/1.3),0)'[outv_final];
      FILTER
    end

    def watermark_font_file
      "./lib/social_stream/Lato-Regular.ttf"
    end

    def watermark_file
      "./lib/social_stream/watermark.png"
    end

    def intro_outro_font_file
      "./lib/social_stream/Ubuntu-Medium.ttf"
    end

    def ffmpeg_process
      return @ffmpeg_process if @ffmpeg_process

      cmd = <<-CMD
        ffmpeg -hide_banner -loglevel error -y -safe 0 -i #{@concat_pls} \
        -preset ultrafast -pix_fmt yuv420p -r 30 -g 30 -c:v libx264 -c:a aac -f hls \
        -hls_time 1 -hls_list_size 0 -hls_flags append_list \
        -hls_segment_filename "#{@main_m3u8.dirname}/#{@main_m3u8.file_name}_%09d.ts" \
        '#{@main_m3u8.path}'
      CMD

      @ffmpeg_process = IO.popen(cmd, "w")
    end

    def add_intro
      @add_intro = false
      input = File.open("./lib/social_stream/intro.mkv")
      @intro = StreamMerger::StreamFile.new(file_name: "intro", extension: ".mkv")
      intro_outro_command(input, @intro)
      concat_feed([@intro], finish: false)
      sleep 2
    end

    def add_outro
      input = File.open("./lib/social_stream/outro.mkv")
      @outro = StreamMerger::StreamFile.new(file_name: "outro", extension: ".mkv")
      intro_outro_command(input, @outro)
      concat_feed([@outro], finish: true)
      sleep 2
    end
  end
end
