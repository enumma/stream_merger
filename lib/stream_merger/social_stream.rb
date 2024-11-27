# frozen_string_literal: false

module StreamMerger
  # SocialStream
  class SocialStream # rubocop:disable Metrics/ClassLength
    include Concat
    include MergerUtils
    include Utils

    COMMON_RESOLUTION = "1080x1920".freeze # Define the common resolution for scaling
    IO_FONTSIZE = 44 # Intro and outro fontsize
    W_FONTSIZE = 32 # Watermark fontsize

    def initialize(conference, handle:, stream_keys:)
      @handle = handle
      @stream_keys = stream_keys
      file_name = file_name_with_timestamp("#{conference.conference_id}Social")
      @main_file = StreamFile.new(file_name:, extension: ".m3u8")
      @concat_pls = StreamFile.new(file_name: "social-concat#{SecureRandom.hex}", extension: ".txt", type: "fifo").path
      @add_intro = true
      @stream_files = []
    end

    def concat_social(stream_files, finish:)
      # add_intro if @add_intro

      # return add_outro if finish

      files = stream_files.map do |input|
        output = StreamMerger::StreamFile.new(file_name: "social-output", extension: ".mkv")
        watermark_command(input, output)
        @stream_files << output
        output
      end

      concat_feed(files, finish:)
      social_processes
    end

    def social_processes # rubocop:disable Metrics/MethodLength
      @stream_keys.each do |type, stream_key|
        case type
        when "YoutubeStream"
          # cmd = <<-CMD
          #   sleep 5
          #   ffmpeg -live_start_index 0 -re -max_reload 1000000 -m3u8_hold_counters 1000000 -i #{@main_file.path} \
          #   -c:v copy -c:a copy -hls_time 1 -hls_list_size 0 \
          #   -http_persistent 1 -method POST \
          #   'https://a.upload.youtube.com/http_upload_hls?cid=#{stream_key}&copy=0&file=master.m3u8'
          # CMD

          # cmd = <<-CMD
          #   sleep 15
          #   ffmpeg -hide_banner -loglevel error -y \
          #   -i "#{intro_file}" \
          #   -live_start_index 0 -re -max_reload 1000000 -m3u8_hold_counters 1000000 -i "#{@main_file.path}" \
          #   -i "#{outro_file}" \
          #   -filter_complex "#{filter_complex}" \
          #   -map "[outv_final]" -map "[outa]" -flags +global_header -c:v libx264 \
          #   -tune zerolatency -preset ultrafast \
          #   -max_delay 500000 -bufsize 16000k -c:a aac -hls_time 1 -hls_list_size 0 -r 30 -g 30 \
          #   -http_persistent 1 -method POST \
          #   'https://a.upload.youtube.com/http_upload_hls?cid=#{stream_key}&copy=0&file=master.m3u8'
          # CMD
          cmd = <<-CMD
          sleep 15
          ffmpeg -hide_banner -loglevel error -y \
          -i "#{intro_file}" \
          -live_start_index 0 -re -max_reload 1000000 -m3u8_hold_counters 1000000 -i "#{@main_file.path}" \
          -i "#{outro_file}" \
          -filter_complex "#{filter_complex}" \
          -map "[outv_final]" -map "[outa]" -flags +global_header -c:v libx264 \
          -tune zerolatency -preset ultrafast \
          -max_delay 500000 -bufsize 16000k -c:a aac -hls_time 1 -hls_list_size 0 -r 30 -g 30 \
          asocial.m3u8
          CMD
          @youtube_process ||= IO.popen(cmd, "w")
        end
      end
    end

    def wait_to_finish
      Process.wait(ffmpeg_process.pid) if ffmpeg_process
      Process.wait(@youtube_process.pid) if @youtube_process
    end

    def purge!
      kill_process(ffmpeg_process)
      kill_process(@youtube_process)
      @stream_files.each(&:delete) # Delete stream aux files
      File.delete(@concat_pls) if File.exist?(@concat_pls) # Delete concatenation list
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

    attr_reader :handle

    def watermark_command(input, output)
      `ffmpeg -hide_banner -loglevel error -y \
       -i "#{input.path}" -i "#{watermark_file}" \
       -filter_complex "#{watermark_filter_complex}" \
       -map "[outv_final]" -map 0:a \
       -c:v libx264 -crf 23 -preset ultrafast \
       -c:a aac -b:a 192k -ar 48000 "#{output.path}"`
      output
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
        #{@main_file.path}
      CMD

      @ffmpeg_process = IO.popen(cmd, "w")
    end

    def add_intro
      @add_intro = false
      input = File.open("./lib/social_stream/intro.mkv")
      @intro = StreamMerger::StreamFile.new(file_name: "intro", extension: ".mkv")
      intro_outro_command(input, @intro)
      concat_feed([@intro], finish: false)
    end

    def add_outro
      input = File.open("./lib/social_stream/outro.mkv")
      @outro = StreamMerger::StreamFile.new(file_name: "outro", extension: ".mkv")
      intro_outro_command(input, @outro)
      concat_feed([@outro], finish: true)
    end

    def intro_file
      input = File.open("./lib/social_stream/intro.mkv")
      input.path
    end

    def outro_file
      input = File.open("./lib/social_stream/outro.mkv")
      input.path
    end

    def filter_complex
      <<~FILTER
        [0:v]scale=#{COMMON_RESOLUTION}[intro];
        [intro]drawtext=fontfile=#{intro_outro_font_file}:text='#{handle}':fontsize=#{IO_FONTSIZE}:fontcolor=#1E1E1E:x=(w-text_w)/2:y=(h-text_h)/2+223:alpha='if(gte(t,1.3),min(1,(t-1.3)/1.3),0)'[overlayed_intro];
        [1:v]scale=#{COMMON_RESOLUTION}[main];
        [2:v]scale=#{COMMON_RESOLUTION}[outro];
        [outro]drawtext=fontfile=#{intro_outro_font_file}:text='#{handle}':fontsize=#{IO_FONTSIZE}:fontcolor=#1E1E1E:x=(w-text_w)/2:y=(h-text_h)/2+223:alpha='if(gte(t,1.3),min(1,(t-1.3)/1.3),0)'[overlayed_outro];
        [overlayed_intro][0:a][main][1:a][overlayed_outro][2:a]concat=n=3:v=1:a=1[outv][outa]; \
        [outv]format=yuv420p[outv_final]
      FILTER
    end
  end
end
