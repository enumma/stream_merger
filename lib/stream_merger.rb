# frozen_string_literal: true

require "json"
require "active_support/time"
require_relative "stream_merger/utils"
require_relative "stream_merger/merger_utils"
require_relative "stream_merger/conference"
require_relative "stream_merger/playlist"
require_relative "stream_merger/segment"
require_relative "stream_merger/version"

# StreamMerger
module StreamMerger
  class Error < StandardError; end
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end

  def self.merge
    require "byebug"
    first_name = "ewbmlXE8Py7L-2024-11-01_19-51-01.198"
    second_name = "ZqueuFbL1FQj-2024-11-01_19-51-01.945"
    files = []
    conference = StreamMerger::Conference.new
    i = 0
    loop do
      file_a = Dir.glob("./spec/fixtures/*").select do |f|
        f.match(first_name) && f.end_with?(".ts") && !files.include?(f)
      end.first
      file_b = Dir.glob("./spec/fixtures/*").select do |f|
        f.match(second_name) && f.end_with?(".ts") && !files.include?(f)
      end.first
      break if file_a.nil? && file_b.nil?

      files << file_a
      files << file_b
      files = files.compact
      conference.update(files.map { |f| File.expand_path(f) })
      puts conference.build_instructions.inspect
      conference.execute_instructions
      if i == 1
        byebug
        raise "wa"
      end

      sleep 0.5 # simulate latency
      i += 1
    end
  end
end
