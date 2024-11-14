# frozen_string_literal: true

RSpec.describe StreamMerger::Conference do # rubocop:disable Metrics/BlockLength
  let(:files) { fixture_files.select { |file| file.end_with?(".ts") || file.end_with?(".m3u8") } }
  let(:instructions) { JSON.parse(File.open(file_path("instructions.json")).read) }
  let(:conference) { StreamMerger::Conference.new }

  context "when building a playlist" do
    before do
      conference.update(files)
    end

    after do
      conference.purge!
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
      expect(trim_file_names(conference.build_instructions(pop: false)).to_json).to \
        eq(trim_file_names(instructions).to_json)
    end

    xit "execute instructions" do
      conference.execute
    end
  end

  def trim_file_names(instructions)
    instructions.each do |array|
      array.each do |hash|
        hash[:file] = "" if hash[:file]
        hash["file"] = "" if hash["file"]
      end
    end
    instructions
  end
end
