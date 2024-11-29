# frozen_string_literal: true

module StreamMerger
  # MergeUtils
  module MergerUtils
    def merge_streams(instructions, output = "output")
      merger = Merger.new(instructions)
      cmd = base_ffmpeg_command(merger.inputs, merger.grid_filter, output)
      run_ffmpeg(cmd)
    end

    def base_ffmpeg_command(input_files, filter_complex, output = "output.mkv")
      <<~CMD
        ffmpeg -hide_banner -loglevel error #{input_files} \
          -y -filter_complex "#{filter_complex}" \
          -map "[video]" -map "[audio]" -flags +global_header -c:v libx264 \
          -tune zerolatency -preset ultrafast -max_delay 500000 -b:v 8000k -bufsize 16000k -r 30 -g 30 \
          -c:a aac -b:a 192k -ar 48000 \
          #{output}
      CMD
    end

    def run_ffmpeg(command)
      process = IO.popen(command)
      Process.waitpid2(process.pid)
      # _pid, status = Process.waitpid2(process.pid)

      # if status.success?
      #   puts "FFmpeg completed successfully."
      # else
      #   puts "FFmpeg failed with exit status: #{status.exitstatus}"
      # end
    end
  end
end
