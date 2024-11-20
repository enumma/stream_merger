# frozen_string_literal: true

RSpec.describe StreamMerger::Conference do # rubocop:disable Metrics/BlockLength
  let(:files) { JSON.parse(File.open(file_path("files.json")).read) }
  let(:instructions) { JSON.parse(File.open(file_path("instructions.json")).read) }
  let(:conference) { StreamMerger::Conference.new }

  context "when building a playlist" do
    before do
      conference.update(files)
    end

    after do
      conference.purge!
    end

    it "builds playlists correctly" do
      expect(conference.playlists.map { |p| p.segments.size }).to eq([9, 7])
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
        hash[:segment_id] = "" if hash[:segment_id]
        hash["file"] = "" if hash["file"]
        hash["segment_id"] = "" if hash["segment_id"]
      end
    end
    instructions
  end
end
