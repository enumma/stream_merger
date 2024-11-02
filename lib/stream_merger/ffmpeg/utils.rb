# frozen_string_literal: true

module StreamMerger
  module Ffmpeg
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
        `ffmpeg -i "#{url}" 2>&1 | grep "Duration" | \
         awk '{print $2}' | sed 's/,//g' | \
         awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }'`.to_f
      end
    end
  end
end
