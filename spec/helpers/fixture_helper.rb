# frozen_string_literal: true

module FixtureHelper
  def file_path(filename)
    "./spec/fixtures/#{filename}"
  end

  def fixture_files
    Dir.glob("./spec/fixtures/*")
  end
end
