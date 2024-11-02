# frozen_string_literal: true

module StreamMerger
  module Ffmpeg
    # Utils
    module Utils
      def ffmpeg_duration(url)
        `ffmpeg -i "#{url}" 2>&1 | grep "Duration" | \
         awk '{print $2}' | sed 's/,//g' | \
         awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }'`.to_f
      end
    end
  end
end
