# frozen_string_literal: true

RSpec.describe StreamMerger::Playlist do
  let(:segment1) { StreamMerger::Segment.new(file: file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000000.ts")) }
  let(:segment2) { StreamMerger::Segment.new(file: file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000001.ts")) }
  let(:playlist) { StreamMerger::Playlist.new(file: file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8")) }

  it "adds a segment" do
    expect(playlist << segment1).to eq [segment1]
  end

  it "orders segments" do
    playlist << segment2
    playlist << segment1
    expect(playlist.segments).to eq [segment1, segment2]
  end

  it "does not repeat segments" do
    playlist << segment1
    playlist << segment1
    expect(playlist.segments).to eq [segment1]
  end
end
