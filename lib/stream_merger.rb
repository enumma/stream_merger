# frozen_string_literal: true

require "active_support/time"
require_relative "stream_merger/ffmpeg/utils"
require_relative "stream_merger/playlist"
require_relative "stream_merger/segment"
require_relative "stream_merger/version"

module StreamMerger
  class Error < StandardError; end
  # Your code goes here...
end
