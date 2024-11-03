# frozen_string_literal: true

module StreamMerger
  # MergeUtils
  module MergerUtils
    ONE_GRID = "[0:v]scale=1080:1920[video]"
    TWO_GRID = "[0:v]scale=1080:960[top]; \
         [1:v]scale=1080:960[bottom]; \
         [top][bottom]vstack=inputs=2:shortest=1[video]; \
         [0:a][1:a]amix=inputs=2:duration=shortest:dropout_transition=3[audio]"
    THREE_GRID = "[0:v]scale=1080:960[top]; \
         [1:v]scale=540:360[bottom_left]; \
         [2:v]scale=540:360[bottom_right]; \
         [bottom_left][bottom_right]hstack=inputs=2[bottom]; \
         [top][bottom]vstack=inputs=2:shortest=1[video]; \
         [0:a][1:a][2:a]amix=inputs=3:duration=shortest:dropout_transition=3[audio]"
    FOUR_GRID = "[0:v]scale=540:960[top_left]; \
         [1:v]scale=540:960[top_right]; \
         [2:v]scale=540:360[bottom_left]; \
         [3:v]scale=540:360[bottom_right]; \
         [top_left][top_right]hstack=inputs=2[top]; \
         [bottom_left][bottom_right]hstack=inputs=2[bottom]; \
         [top][bottom]vstack=inputs=2:shortest=1[video]; \
         [0:a][1:a][2:a][3:a]amix=inputs=4:duration=shortest:dropout_transition=3[audio]"
    GRIDS = [ONE_GRID, TWO_GRID, THREE_GRID, FOUR_GRID].freeze

    def merge_streams(streams)
      cmd = base_ffmpeg_command(inputs(streams), grid(streams))
      run_ffmpeg(cmd)
    end

    def base_ffmpeg_command(input_files, filter_complex)
      <<~CMD
        ffmpeg #{input_files} \
          -filter_complex "#{filter_complex}" \
          -map "[video]" -map "[audio]" -flags +global_header -c:v libx264 \
          -tune zerolatency -preset veryfast -max_delay 500000 -b:v 8000k -bufsize 16000k -r 30 -g 60 \
          -c:a aac -b:a 128k -ar 44100 \
          -f hls -hls_time 1 \
          -hls_playlist_type event \
          -hls_flags delete_segments+append_list output.m3u8
      CMD
    end

    def inputs(streams)
      streams.map do |stream|
        "-i \"#{stream}\""
      end.join(" ")
    end

    def grid(streams)
      str = GRIDS[streams.size - 1]
      raise ArgumentError, "Unsupported grid for #{streams.size}" if str.nil?

      str
    end

    def run_ffmpeg(command)
      puts "Executing FFmpeg command: #{command}"
      process = IO.popen(command)
      _pid, status = Process.waitpid2(process.pid)

      if status.success?
        puts "FFmpeg completed successfully."
      else
        puts "FFmpeg failed with exit status: #{status.exitstatus}"
      end
    end
  end
end
