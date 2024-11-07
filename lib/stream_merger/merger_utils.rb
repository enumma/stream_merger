# frozen_string_literal: true

module StreamMerger
  # MergeUtils
  module MergerUtils # rubocop:disable Metrics/ModuleLength
    OUTPUT_W = 1080.0
    OUTPUT_H = 1920.0
    ONE_GRID = "[0:v]CROP_I,scale=#{OUTPUT_W}:#{OUTPUT_H}[video]; \
                [0:a]amix=inputs=1:duration=shortest:dropout_transition=3[audio]".freeze
    TWO_GRID = "[0:v]CROP_I,scale=#{OUTPUT_W}:#{OUTPUT_H / 2}[top]; \
         [1:v]CROP_I,scale=#{OUTPUT_W}:#{OUTPUT_H / 2}[bottom]; \
         [top][bottom]vstack=inputs=2:shortest=1[video]; \
         [0:a][1:a]amix=inputs=2:duration=shortest:dropout_transition=3[audio]".freeze
    THREE_GRID = "[0:v]CROP_I,scale=#{OUTPUT_W}:#{OUTPUT_H / 2}[top]; \
         [1:v]CROP_I,scale=#{OUTPUT_W / 2}:#{OUTPUT_H / 2}[bottom_left]; \
         [2:v]CROP_I,scale=#{OUTPUT_W / 2}:#{OUTPUT_H / 2}[bottom_right]; \
         [bottom_left][bottom_right]hstack=inputs=2[bottom]; \
         [top][bottom]vstack=inputs=2:shortest=1[video]; \
         [0:a][1:a][2:a]amix=inputs=3:duration=shortest:dropout_transition=3[audio]".freeze
    FOUR_GRID = "[0:v]CROP_I,scale=#{OUTPUT_W / 2}:#{OUTPUT_H / 2}[top_left]; \
         [1:v]CROP_I,scale=#{OUTPUT_W / 2}:#{OUTPUT_H / 2}[top_right]; \
         [2:v]CROP_I,scale=#{OUTPUT_W / 2}:#{OUTPUT_H / 2}[bottom_left]; \
         [3:v]CROP_I,scale=#{OUTPUT_W / 2}:#{OUTPUT_H / 2}[bottom_right]; \
         [top_left][top_right]hstack=inputs=2[top]; \
         [bottom_left][bottom_right]hstack=inputs=2[bottom]; \
         [top][bottom]vstack=inputs=2:shortest=1[video]; \
         [0:a][1:a][2:a][3:a]amix=inputs=4:duration=shortest:dropout_transition=3[audio]".freeze

    GRIDS = [ONE_GRID, TWO_GRID, THREE_GRID, FOUR_GRID].freeze

    OUTPUT_RESOLUTIONS = [
      [{ w: OUTPUT_W, h: OUTPUT_H, o: :vertical }],
      [{ w: OUTPUT_W, h: OUTPUT_H / 2, o: :horizontal }, { w: OUTPUT_W, h: OUTPUT_H / 2, o: :horizontal }],
      [{ w: OUTPUT_W, h: OUTPUT_H / 2, o: :horizontal }, { w: OUTPUT_W / 2, h: OUTPUT_H / 2, o: :vertical },
       { w: OUTPUT_W / 2, h: OUTPUT_H / 2, o: :vertical }],
      [{ w: OUTPUT_W / 2, h: OUTPUT_H / 2, o: :vertical }, { w: OUTPUT_W / 2, h: OUTPUT_H / 2, o: :vertical },
       { w: OUTPUT_W / 2, h: OUTPUT_H / 2, o: :vertical },
       { w: OUTPUT_W / 2, h: OUTPUT_H / 2, o: :vertical }]
    ].freeze

    def merge_streams(instructions, output = "output")
      cmd = base_ffmpeg_command(inputs(instructions), generate_grid_filter(instructions), output)
      run_ffmpeg(cmd)
    end

    # def base_ffmpeg_command(input_files, filter_complex, output = "output")
    #   <<~CMD
    #     ffmpeg #{input_files} \
    #       -err_detect aggressive \
    #       -filter_complex "#{filter_complex}" \
    #       -map "[video]" -map "[audio]" -flags +global_header -c:v libx264 \
    #       -tune zerolatency -preset veryfast -max_delay 500000 -b:v 8000k -bufsize 16000k -r 30 -g 60 \
    #       -c:a aac -b:a 128k -ar 44100 \
    #       -f hls -hls_time 5 \
    #       -hls_playlist_type event \
    #       -hls_flags delete_segments+append_list #{output}.m3u8
    #   CMD
    # end

    def base_ffmpeg_command(input_files, filter_complex, output = "output")
      <<~CMD
        ffmpeg #{input_files} \
          -err_detect aggressive \
          -filter_complex "#{filter_complex}" \
          -map "[video]" -map "[audio]" -flags +global_header -c:v libx264 \
          -tune zerolatency -preset veryfast -max_delay 500000 -b:v 8000k -bufsize 16000k -r 30 -g 60 \
          -c:a aac -b:a 128k -ar 44100 \
          #{output}.mkv
      CMD
    end

    def inputs(instructions)
      streams = instructions.map { |instruction| instruction[:file] }
      input_commands = streams.each_with_index.map do |stream, index|
        instruction = instructions[index]
        start_seconds = instruction[:start_seconds]
        end_seconds = instruction[:end_seconds]
        duration = (end_seconds - start_seconds).round(3)
        "-ss '#{start_seconds}' -i \"#{stream}\" -t #{duration}"
      end
      input_commands.join(" ")
    end

    def generate_grid_filter(streams)
      validate_grid_size(streams.size)

      grid_layout = GRIDS[streams.size - 1]
      streams.each_with_index do |stream, idx|
        crop_filter = build_crop_filter(stream, idx, streams.size)
        grid_layout = grid_layout.sub("CROP_I", crop_filter)
      end

      grid_layout
    end

    def calculate_crop_filter(input_width, input_height, resolution)
      if resolution[:o] == :horizontal
        crop_horizontal(input_width, input_height)
      else
        crop_vertical(input_width, input_height)
      end
    end

    def crop_horizontal(width, height)
      ar_w = height * (OUTPUT_H / OUTPUT_W)
      ar_h = width * (OUTPUT_W / OUTPUT_H)

      dest_w = height < ar_h ? ar_w : width
      dest_h = width < ar_w ? ar_h : height
      dest_x = dest_w == width ? 0 : (width - dest_w).to_f / 2
      dest_y = dest_h == height ? 0 : (height - dest_h).to_f / 2

      "crop=#{dest_w}:#{dest_h}:#{dest_x}:#{dest_y}"
    end

    def crop_vertical(width, height)
      ar_h = width * (OUTPUT_H / OUTPUT_W)
      ar_w = height * (OUTPUT_W / OUTPUT_H)

      dest_w = height < ar_h ? ar_w : width
      dest_h = width < ar_w ? ar_h : height
      dest_x = dest_w == width ? 0 : (width - dest_w) / 2
      dest_y = dest_h == height ? 0 : (height - dest_h) / 2

      "crop=#{dest_w}:#{dest_h}:#{dest_x}:#{dest_y}"
    end

    def validate_grid_size(size)
      raise ArgumentError, "Unsupported grid for #{size}" if GRIDS[size - 1].nil?
    end

    def build_crop_filter(stream, index, total_streams)
      input_width = stream[:width]
      input_height = stream[:height]
      resolution = OUTPUT_RESOLUTIONS[total_streams - 1][index]

      calculate_crop_filter(input_width, input_height, resolution)
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
