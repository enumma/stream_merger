# frozen_string_literal: true

module StreamMerger
  # Concat
  module Concat
    def concat_feed(stream_files, finish: false)
      return if stream_files.empty?

      ffmpeg_process
      write_concat_file(stream_files, finish:)
    end

    def write_concat_file(stream_files, finish: false)
      if File.exist?(@concat_pls) && finish
        File.delete(@concat_pls)
        return
      end
      concat_content = build_concat_content(stream_files, finish:)
      pid = fork do
        recreate_concat_pls
        file = File.open(@concat_pls, "w")
        file.write(concat_content)
      end
      Process.wait(pid)
    end

    def build_concat_content(stream_files, finish:)
      concat_header = "ffconcat version 1.0\n"
      file_entries = stream_files.map { |file| "file '#{file.path}'\n" }.join
      self_reference = (finish ? "" : "file '#{@concat_pls}'\noption safe 0")
      "#{concat_header}#{file_entries}#{self_reference}\n"
    end

    def recreate_concat_pls
      File.delete(@concat_pls) if File.exist?(@concat_pls)
      File.mkfifo(@concat_pls)
      File.chmod(0o666, @concat_pls)
    end
  end
end
