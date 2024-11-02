# frozen_string_literal: true

module StreamMerger
  # Utils
  module Utils
    require "time"

    TIMESTAMP_REGEX = /\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.\d{4}/
    TIMESTAMP_FORMAT = "%Y-%m-%d_%H-%M-%S.%L"

    def file_timestamp(file)
      timestamp_str = file[TIMESTAMP_REGEX]
      return unless timestamp_str

      Time.strptime(timestamp_str, TIMESTAMP_FORMAT)
    rescue ArgumentError
      nil
    end

    def ffmpeg_duration(url)
      warn "ffmpeg_duration is not accurate"
      `ffmpeg -i "#{url}" 2>&1 | grep "Duration" | \
         awk '{print $2}' | sed 's/,//g' | \
         awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }'`.to_f
    end

    def ffmpeg_exact_duration(url)
      `ffprobe -v error -select_streams v -of \
      default=noprint_wrappers=1:nokey=1 -show_entries stream=duration #{url}`.to_f
    end

    def ffmpeg_data(url)
      warn "ffmpeg_data is not accurate"
      # Execute the ffmpeg command and capture its output
      output = `ffmpeg -i "#{url}" 2>&1`

      # Extract the duration using regex
      duration_match = output.match(/Duration: (\d+:\d+:\d+\.\d+)/)
      duration = duration_match ? convert_to_seconds(duration_match[1]) : nil

      # Extract the start time using regex (if available in the output)
      start_match = output.match(/start: (\d+\.\d+)/)
      start = start_match ? start_match[1].to_f : nil

      # Extract the bitrate using regex
      bitrate_match = output.match(%r{bitrate: (\d+ kb/s)})
      bitrate = bitrate_match ? bitrate_match[1] : nil

      { duration: duration, start: start, bitrate: bitrate }
    end

    # Convert duration string (HH:MM:SS.sss) to total seconds
    def convert_to_seconds(duration_str)
      hours, minutes, seconds = duration_str.split(":").map(&:to_f)
      (hours * 3600) + (minutes * 60) + seconds
    end
  end
end
