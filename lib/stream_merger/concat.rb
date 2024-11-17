# frozen_string_literal: true

module StreamMerger
  # Concat
  module Concat
    def ffmpeg_process
      cmd = <<-CMD
        ffmpeg -y -safe 0 -i #{@concat_pls} \
        -preset ultrafast -pix_fmt yuv420p -r 30 -g 30 -c:v libx264 -c:a aac -f hls \
        -hls_time 1 -hls_list_size 0 -hls_flags append_list \
        '#{@main_m3u8.path}'
      CMD

      @ffmpeg_process ||= IO.popen(cmd, "w")
    end

    def stop_ffmpeg_process
      Process.kill("TERM", @ffmpeg_process.pid) if @ffmpeg_process&.pid
    end

    def fn_concat_feed(files, finish: false)
      return if files.empty?

      ffmpeg_process
      write_concat_file(files, finish:)
      # wait_for_ffmpeg
    end

    def write_concat_file(files, finish:)
      concat_content = build_concat_content(files, finish:)
      File.write(@concat_pls, concat_content)
    end

    def build_concat_content(files, finish:)
      concat_header = "ffconcat version 1.0\n"
      file_entries = files.map { |file| "file '#{file.path}'\n" }.join
      self_reference = (finish ? "" : "file '#{@concat_pls}'\n")
      "#{concat_header}#{file_entries}#{self_reference}option safe 0"
    end

    def wait_for_ffmpeg
      sleep 2 # Necessary delay for ffmpeg to process the concatenation
    end
  end
end
