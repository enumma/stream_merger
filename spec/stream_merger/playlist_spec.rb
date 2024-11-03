# frozen_string_literal: true

RSpec.describe StreamMerger::Playlist do
  let(:file1) { file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000000.ts") }
  let(:file2) { file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000001.ts") }
  let(:playlist) { StreamMerger::Playlist.new(file: file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8")) }
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
    segments = playlist << file1
    expect(segments.size).to eq 1
  end

  it "creates a header" do
    expect(playlist.send(:header)).to eq header
  end

  it "creates a body" do
    expect(playlist.send(:body)).to eq body
  end

  it "creates a tmp file" do
    expect(playlist.tempfile.read).to eq([header, body].join("\n"))
  end
end
