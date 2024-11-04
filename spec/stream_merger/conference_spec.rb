# frozen_string_literal: true

RSpec.describe StreamMerger::Conference do
  let(:files) { fixture_files.select { |file| file.end_with?(".ts") || file.end_with?(".m3u8") } }
  let(:instructions) { JSON.parse(File.open(file_path("instructions.json")).read) }
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
      expect(conference.build_instructions.to_json).to eq(instructions.to_json)
    end
  end
end
