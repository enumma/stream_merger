# frozen_string_literal: true

module StreamMerger
  # Concat
  module Concat
    # @ffmpeg_process ||= IO.popen("ffmpeg -y -safe 0 -i #{@concat_pls} -preset ultrafast -pix_fmt yuv420p -r 30 -c:v
    # libx264 -c:a aac all.mkv",
    #                              "w")
    def fn_concat_feed(file)
      cmd = <<-CMD
        ffmpeg -y -safe 0 -i #{@concat_pls} \
        -preset ultrafast -pix_fmt yuv420p -r 30 -c:v libx264 -c:a aac -f hls \
        -hls_time 10 -hls_list_size 0 -hls_segment_filename 'segment_%03d.ts' all.m3u8
      CMD
      @ffmpeg_process ||= IO.popen(cmd, "w")

      # Write the required information to the FIFO
      File.open(@concat_pls, "w") do |fifo|
        fifo.puts "ffconcat version 1.0\nfile '#{file}'\nfile '#{@concat_pls}'\noption safe 0"
      end
    end
  end
end
