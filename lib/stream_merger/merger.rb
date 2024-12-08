# frozen_string_literal: false

module StreamMerger
  # Merger
  class Merger # rubocop:disable Metrics/ClassLength
    OUTPUT_W = 1080.0
    OUTPUT_H = 1920.0
    ONE_GRID = "[0:v]CROP_I,scale=#{OUTPUT_W}:#{OUTPUT_H}[video_grid];".freeze
    TWO_GRID = "[0:v]CROP_I,scale=#{OUTPUT_W}:#{OUTPUT_H / 2}[top]; \
         [1:v]CROP_I,scale=#{OUTPUT_W}:#{OUTPUT_H / 2}[bottom]; \
         [top][bottom]vstack=inputs=2:shortest=1[video_grid];".freeze
    THREE_GRID = "[0:v]CROP_I,scale=#{OUTPUT_W}:#{OUTPUT_H / 2}[top]; \
         [1:v]CROP_I,scale=#{OUTPUT_W / 2}:#{OUTPUT_H / 2}[bottom_left]; \
         [2:v]CROP_I,scale=#{OUTPUT_W / 2}:#{OUTPUT_H / 2}[bottom_right]; \
         [bottom_left][bottom_right]hstack=inputs=2[bottom]; \
         [top][bottom]vstack=inputs=2:shortest=1[video_grid];".freeze
    FOUR_GRID = "[0:v]CROP_I,scale=#{OUTPUT_W / 2}:#{OUTPUT_H / 2}[top_left]; \
         [1:v]CROP_I,scale=#{OUTPUT_W / 2}:#{OUTPUT_H / 2}[top_right]; \
         [2:v]CROP_I,scale=#{OUTPUT_W / 2}:#{OUTPUT_H / 2}[bottom_left]; \
         [3:v]CROP_I,scale=#{OUTPUT_W / 2}:#{OUTPUT_H / 2}[bottom_right]; \
         [top_left][top_right]hstack=inputs=2[top]; \
         [bottom_left][bottom_right]hstack=inputs=2[bottom]; \
         [top][bottom]vstack=inputs=2:shortest=1[video_grid];".freeze

    OUTPUT_RESOLUTIONS = [
      [{ w: OUTPUT_W, h: OUTPUT_H, o: :vertical }],
      [{ w: OUTPUT_W, h: OUTPUT_H / 2, o: :horizontal }, { w: OUTPUT_W, h: OUTPUT_H / 2, o: :horizontal }],
      [{ w: OUTPUT_W, h: OUTPUT_H / 2, o: :horizontal }, { w: OUTPUT_W / 2, h: OUTPUT_H / 2, o: :vertical },
       { w: OUTPUT_W / 2, h: OUTPUT_H / 2, o: :vertical }],
      [{ w: OUTPUT_W / 2, h: OUTPUT_H / 2, o: :vertical }, { w: OUTPUT_W / 2, h: OUTPUT_H / 2, o: :vertical },
       { w: OUTPUT_W / 2, h: OUTPUT_H / 2, o: :vertical },
       { w: OUTPUT_W / 2, h: OUTPUT_H / 2, o: :vertical }]
    ].freeze

    GRIDS = [ONE_GRID, TWO_GRID, THREE_GRID, FOUR_GRID].freeze

    attr_reader :participants, :total_inputs

    def initialize(instructions)
      @participants = instructions
      @total_inputs = @participants.size
    end

    def inputs
      input_commands = []
      participants.each do |instruction|
        input_commands << input(instruction)
      end
      input_commands.join(" ")
    end

    def grid_filter
      grid_layout = participant_grid
      grid_layout = "[0:v]null[video_grid];" unless participants.any?
      grid_layout + video_filter + audio_filter
    end

    private

    def participant_grid
      grid_layout = GRIDS[participants.size - 1]
      participants.each_with_index do |stream, idx|
        crop_filter = build_crop_filter(stream, idx, participants.size)
        grid_layout = grid_layout.sub("CROP_I", crop_filter)
      end
      grid_layout
    end

    def input(instruction)
      stream = instruction[:file]
      start_seconds = instruction[:start_seconds]
      end_seconds = instruction[:end_seconds]
      duration = (end_seconds - start_seconds).round(8)
      "-ss '#{start_seconds}' -i \"#{stream}\" -t #{duration}"
    end

    def build_crop_filter(stream, index, total_streams)
      input_width = stream[:width]
      input_height = stream[:height]
      resolution = OUTPUT_RESOLUTIONS[total_streams - 1][index]

      calculate_crop_filter(input_width, input_height, resolution)
    end

    def calculate_crop_filter(input_width, input_height, resolution)
      if resolution[:o] == :horizontal
        crop_horizontal(input_width, input_height)
      else
        crop_vertical(input_width, input_height)
      end
    end

    def crop_horizontal(width, height)
      ar_w = height * (OUTPUT_W / (OUTPUT_H / 2))
      ar_h = width * ((OUTPUT_H / 2) / OUTPUT_W)

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

    def video_filter
      "[video_grid]null[video];"
    end

    def audio_filter
      filter_str = ""
      participants.each_with_index do |_instruction, index|
        filter_str << "[#{index}:a]"
      end
      # filter_str << "amix=inputs=#{total_inputs}:duration=first:dropout_transition=0,dynaudnorm[audio]"
      filter_str << "amix=inputs=#{total_inputs}:duration=first,volume=#{total_inputs}[audio]"
    end
  end
end
