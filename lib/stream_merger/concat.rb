# frozen_string_literal: true

module StreamMerger
  # Concat
  module Concat
    def concat_feed(stream_files, finish: false)
      return if stream_files.empty?

      ffmpeg_process
      write_concat_file(stream_files, finish:)
      n = stream_files.map { |f| File.size(f.path) / 1_000_000.0 }.sum
      n = 5 if n < 1
      sleep n # sleep for big files
    end

    def write_concat_file(stream_files, finish:)
      concat_content = build_concat_content(stream_files, finish:)
      File.write(@concat_pls, concat_content)
    end

    def build_concat_content(stream_files, finish:)
      concat_header = "ffconcat version 1.0\n"
      file_entries = stream_files.map { |file| "file '#{file.path}'\n" }.join
      self_reference = (finish ? "" : "file '#{@concat_pls}'\n")
      "#{concat_header}#{file_entries}#{self_reference}option safe 0\n"
    end
  end
end
