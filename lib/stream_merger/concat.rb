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

    def fn_concat_feed(file)
      ffmpeg_process
      # Write the required information to the FIFO
      File.open(@concat_pls, "w") do |fifo|
        fifo.puts "ffconcat version 1.0\nfile '#{file}'\nfile '#{@concat_pls}'\noption safe 0"
      end
      sleep 2 # Without this sleep, ffmpeg will not be able to concatenate properly
    end

    def append_to_url_path(url, path_to_add)
      uri = URI.parse(url)
      uri.path = File.join(uri.path, path_to_add) # Append to the existing path
      uri.to_s
    rescue URI::InvalidURIError
      "Invalid URL"
    end
  end
end
