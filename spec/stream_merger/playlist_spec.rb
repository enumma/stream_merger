# frozen_string_literal: true

RSpec.describe StreamMerger::Playlist do
  let(:segment1) { StreamMerger::Segment.new(file: file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000000.ts")) }
  let(:segment2) { StreamMerger::Segment.new(file: file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000001.ts")) }
  let(:playlist) { StreamMerger::Playlist.new(file: file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8")) }
  let(:header) do
    <<~HEADER.chomp
      #EXTM3U
      #EXT-X-VERSION:3
      #EXT-X-TARGETDURATION:#{segment1.duration.to_i}
      #EXT-X-MEDIA-SEQUENCE:0
      #EXT-X-PLAYLIST-TYPE:EVENT
      #EXT-X-DISCONTINUITY
    HEADER
  end
  let(:body) do
    <<~BODY.chomp
      #EXTINF:6.202011,
      ./spec/fixtures/ewbmlXE8Py7L-2024-11-01_19-51-01.198000000000.ts
    BODY
  end

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

  it "creates a header" do
    playlist << segment1
    expect(playlist.send(:header)).to eq header
  end

  it "creates a body" do
    playlist << segment1
    expect(playlist.send(:body)).to eq body
  end

  it "creates a tmp file" do
    playlist << segment1
    expect(playlist.tempfile.read).to eq([header, body].join("\n"))
  end
end
