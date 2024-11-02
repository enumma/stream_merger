# frozen_string_literal: true

RSpec.describe StreamMerger::Conference do
  let(:files) { fixture_files }
  let(:conference) { StreamMerger::Conference.new }

  context "when building a playlist" do
    before do
      conference.update(files)
    end
    it "builds two playlists" do
      expect(conference.playlists.size).to eq(2)
    end

    it "builds first playlist correctly" do
      expect(conference.playlists[0].segments.size).to eq(9)
    end

    it "builds second playlist correctly" do
      expect(conference.playlists[1].segments.size).to eq(7)
    end

    it "builds a timeline" do
      timestamps = conference.send(:timeline).flatten.uniq
      expect(timestamps).to eq(timestamps.sort)
    end

    it "builds instructions" do
      instructions = conference.build_instructions
      expect(instructions).to eq([
                                   [{
                                     file: "./spec/fixtures/ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8", start_seconds: 0, end_seconds: 0.747
                                   }],
                                   [{
                                     file: "./spec/fixtures/ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8", start_seconds: 0.747, end_seconds: 32.689077000000005
                                   },
                                    {
                                      file: "./spec/fixtures/ZqueuFbL1FQj-2024-11-01_19-51-01.945.m3u8", start_seconds: 0, end_seconds: 31.942077
                                    }],
                                   [{ file: "./spec/fixtures/ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8",
                                      start_seconds: 32.689077000000005, end_seconds: 43.534099 }]
                                 ])
    end
  end
end
