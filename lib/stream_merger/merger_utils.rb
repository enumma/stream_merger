# frozen_string_literal: true

module StreamMerger
  module MergerUtils
    def merge_streams(streams)
      cmd = case streams.size
            when 1 then single_stream(*streams)
            when 2 then merge_two_streams(*streams)
            when 3 then merge_three_streams(*streams)
            when 4 then merge_four_streams(*streams)
            else
              raise ArgumentError, "Unsupported number of streams"
            end
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

    def single_stream(stream)
      base_ffmpeg_command(
        "-i \"#{stream}\"",
        "[0:v]scale=1080:1920[video]",
        "[0:a]"
      )
    end

    def merge_two_streams(stream1, stream2)
      base_ffmpeg_command(
        "-i \"#{stream1}\" -i \"#{stream2}\"",
        "[0:v]scale=640:720[top]; [1:v]scale=640:720[bottom]; [top][bottom]vstack=inputs=2:shortest=1[video]; [0:a][1:a]amix=inputs=2:duration=shortest:dropout_transition=3[audio]"
      )
    end

    def merge_three_streams(stream1, stream2, stream3)
      base_ffmpeg_command(
        "-i \"#{stream1}\" -i \"#{stream2}\" -i \"#{stream3}\"",
        "[0:v]scale=1280:720[top]; [1:v]scale=640:360[bottom_left]; [2:v]scale=640:360[bottom_right]; [bottom_left][bottom_right]hstack=inputs=2[bottom]; [top][bottom]vstack=inputs=2:shortest=1[video]; [0:a][1:a][2:a]amix=inputs=3:duration=shortest:dropout_transition=3[audio]"
      )
    end

    def merge_four_streams(stream1, stream2, stream3, stream4)
      base_ffmpeg_command(
        "-i \"#{stream1}\" -i \"#{stream2}\" -i \"#{stream3}\" -i \"#{stream4}\"",
        "[0:v]scale=640:360[top_left]; [1:v]scale=640:360[top_right]; [2:v]scale=640:360[bottom_left]; [3:v]scale=640:360[bottom_right]; [top_left][top_right]hstack=inputs=2[top]; [bottom_left][bottom_right]hstack=inputs=2[bottom]; [top][bottom]vstack=inputs=2:shortest=1[video]; [0:a][1:a][2:a][3:a]amix=inputs=4:duration=shortest:dropout_transition=3[audio]"
      )
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
