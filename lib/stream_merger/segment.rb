# frozen_string_literal: true

module StreamMerger
  # Segment
  class Segment
    include Utils

    attr_reader :song, :segment_id, :file, :start_time, :end_time, :last_modified, :mkv, :duration

    def initialize(file:, last_modified:)
      @song = !file.match("song").nil?
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

    private

    def set_mkv
      @mkv = Tempfile.new([SecureRandom.hex, ".mkv"])
      if song
        `ffmpeg -hide_banner -loglevel error -y -i "#{file}" -r 30 -c:v copy -c:a flac "#{@mkv.path}"`
      else
        `ffmpeg -hide_banner -loglevel error -y -i "#{file}" -vf "hflip" -r 30 -c:a flac "#{@mkv.path}"`
      end

      @duration = ffmpeg_duration(@mkv.path)
    end
  end
end
