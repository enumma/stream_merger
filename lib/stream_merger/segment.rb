# frozen_string_literal: true

module StreamMerger
  # Segment
  class Segment
    include Utils

    attr_reader :segment_id, :file, :start_time, :end_time, :last_modified, :mkv, :duration

    def initialize(file:, last_modified:)
      @segment_id = SecureRandom.hex
      @file = file
      @last_modified = last_modified
      set_mkv
    end

    def set_timestamps(timestamp:)
      @start_time = timestamp
      @end_time = timestamp + duration.seconds
    end

    def seconds(timestamp)
      timestamp - start_time
    end

    def initial_timestamp
      file_timestamp(file)
    end

    def purge
      File.delete(@mkv.path) if File.exist?(@mkv.path)
    end

    private

    def set_mkv
      @mkv = StreamFile.new(file_name: SecureRandom.hex, extension: ".mkv", type: "normal")

      `ffmpeg -hide_banner -loglevel error -y -i "#{file}" -vf "hflip" -r 30 -c:a aac "#{@mkv.path}"`
      @duration = ffmpeg_duration(@mkv.path)
    end
  end
end
