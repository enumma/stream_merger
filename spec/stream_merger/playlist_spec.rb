# frozen_string_literal: true

RSpec.describe StreamMerger::Playlist do
  let(:file1) { file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000000.ts") }
  let(:file2) { file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000001.ts") }
  let(:playlist) { StreamMerger::Playlist.new(file_name: "ewbmlXE8Py7L-2024-11-01_19-51-01.198") }
  let(:header) { File.open(file_path("header.txt")).read }
  let(:body) { File.open(file_path("body.txt")).read }

  before do
    playlist << file1
  end

  it "orders segments" do
    segments = playlist << file2
    expect(segments.size).to eq 2
  end

  it "does not repeat segments" do
    expect(playlist << file1).to eq nil
  end
end
