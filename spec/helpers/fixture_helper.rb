# frozen_string_literal: true

module FixtureHelper
  def file_path(filename)
    File.expand_path("./spec/fixtures/#{filename}")
  end

  def fixture_files
    Dir.glob("./spec/fixtures/*").select { |f| f.end_with?(".ts") }.map { |f| File.expand_path(f) }
  end
end
