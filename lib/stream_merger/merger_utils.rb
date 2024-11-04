# frozen_string_literal: true

module StreamMerger
  # MergeUtils
  module MergerUtils # rubocop:disable Metrics/ModuleLength
    ONE_GRID = "[0:v]CROP_I,scale=1080:1920[video]; \
                [0:a]amix=inputs=1:duration=shortest:dropout_transition=3[audio]"
    TWO_GRID = "[0:v]CROP_I,scale=1080:960[top]; \
         [1:v]CROP_I,scale=1080:960[bottom]; \
         [top][bottom]vstack=inputs=2:shortest=1[video]; \
         [0:a][1:a]amix=inputs=2:duration=shortest:dropout_transition=3[audio]"
    THREE_GRID = "[0:v]CROP_I,scale=1080:960[top]; \
         [1:v]CROP_I,scale=540:960[bottom_left]; \
         [2:v]CROP_I,scale=540:960[bottom_right]; \
         [bottom_left][bottom_right]hstack=inputs=2[bottom]; \
         [top][bottom]vstack=inputs=2:shortest=1[video]; \
         [0:a][1:a][2:a]amix=inputs=3:duration=shortest:dropout_transition=3[audio]"
    FOUR_GRID = "[0:v]CROP_I,scale=540:960[top_left]; \
         [1:v]CROP_I,scale=540:960[top_right]; \
         [2:v]CROP_I,scale=540:960[bottom_left]; \
         [3:v]CROP_I,scale=540:960[bottom_right]; \
         [top_left][top_right]hstack=inputs=2[top]; \
         [bottom_left][bottom_right]hstack=inputs=2[bottom]; \
         [top][bottom]vstack=inputs=2:shortest=1[video]; \
         [0:a][1:a][2:a][3:a]amix=inputs=4:duration=shortest:dropout_transition=3[audio]"

    GRIDS = [ONE_GRID, TWO_GRID, THREE_GRID, FOUR_GRID].freeze

    OUTPUT_RESOLUTIONS = [
      [{ w: 1080, h: 1920 }],
      [{ w: 1080, h: 960 }, { w: 1080, h: 960 }],
      [{ w: 1080, h: 960 }, { w: 540, h: 960 }, { w: 540, h: 960 }],
      [{ w: 540, h: 960 }, { w: 540, h: 960 }, { w: 540, h: 960 },
       { w: 540, h: 960 }]
    ].freeze

    def merge_streams(instructions, output = "output.m3u8")
      cmd = base_ffmpeg_command(inputs(instructions), generate_grid_filter(instructions), output)
      run_ffmpeg(cmd)
    end

    def base_ffmpeg_command(input_files, filter_complex, output = "output.m3u8")
      <<~CMD
        ffmpeg #{input_files} \
          -filter_complex "#{filter_complex}" \
          -map "[video]" -map "[audio]" -flags +global_header -c:v libx264 \
          -tune zerolatency -preset veryfast -max_delay 500000 -b:v 8000k -bufsize 16000k -r 30 -g 60 \
          -c:a aac -b:a 128k -ar 44100 \
          -f hls -hls_time 5 \
          -hls_playlist_type event \
          -hls_flags delete_segments+append_list #{output}
      CMD
    end

    def inputs(instructions)
      streams = instructions.map { |instruction| instruction[:file] }
      input_commands = streams.each_with_index.map do |stream, index|
        instruction = instructions[index]
        start_time = instruction[:start_seconds]
        "-ss #{start_time} -i \"#{stream}\" -to #{instruction[:end_seconds]}"
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

    def calculate_crop_filter(input_width, input_height, target_width, target_height)
      input_aspect = input_width.to_f / input_height
      target_aspect = target_width.to_f / target_height

      if input_aspect > target_aspect
        crop_width, crop_x = calculate_width_crop(input_height, target_aspect, input_width)
        "crop=#{crop_width}:#{input_height}:#{crop_x}:0"
      else
        crop_height, crop_y = calculate_height_crop(input_width, target_height, input_height)
        "crop=#{input_width}:#{crop_height}:0:#{crop_y}"
      end
    end

    def calculate_width_crop(input_height, target_aspect, input_width)
      crop_width = (input_height * target_aspect).to_i
      crop_x = ((input_width - crop_width) / 2).to_i
      [crop_width, crop_x]
    end

    def calculate_height_crop(input_width, target_height, input_height)
      crop_height = (input_width / (target_height.to_f / input_height)).to_i
      crop_y = ((input_height - crop_height) / 2).to_i
      [crop_height, crop_y]
    end

    def validate_grid_size(size)
      raise ArgumentError, "Unsupported grid for #{size}" if GRIDS[size - 1].nil?
    end

    def build_crop_filter(stream, index, total_streams)
      input_width = stream[:width]
      input_height = stream[:height]
      target_width = OUTPUT_RESOLUTIONS[total_streams - 1][index][:w]
      target_height = OUTPUT_RESOLUTIONS[total_streams - 1][index][:h]

      calculate_crop_filter(input_width, input_height, target_width, target_height)
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
