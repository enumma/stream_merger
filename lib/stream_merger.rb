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
end
