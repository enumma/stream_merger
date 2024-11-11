# frozen_string_literal: true

module StreamMerger
  # Concat
  module Concat
    # Notes
    # @ffmpeg_process ||= IO.popen("ffmpeg -y -safe 0 -i #{@concat_pls} -preset ultrafast -pix_fmt yuv420p -r 30 -c:v
    # libx264 -c:a aac all.mkv",
    #                              "w")
    # cmd = <<-CMD
    #   ffmpeg -y -safe 0 -i #{@concat_pls} \
    #   -preset ultrafast -pix_fmt yuv420p -r 30 -g 150 -c:v libx264 -c:a aac -f hls \
    #   -hls_time 5 -hls_list_size 0 -hls_segment_filename './tmp/segment_%03d.ts' './tmp/all.m3u8'
    # CMD
    def ffmpeg_process
      cmd = <<-CMD
        ffmpeg -y -safe 0 -i #{@concat_pls} \
        -preset ultrafast -pix_fmt yuv420p -r 30 -g 150 -c:v libx264 -c:a aac -f hls \
        -hls_time 1 -hls_list_size 0 \
        -method PUT \
        '#{append_to_url_path(StreamMerger.hls_upload_url, "#{@conference_id}.m3u8")}'
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
