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
      expect(conference.playlists[0].segments.size).to eq(7)
    end

    it "builds second playlist correctly" do
      expect(conference.playlists[1].segments.size).to eq(9)
    end
  end
end
