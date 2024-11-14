# frozen_string_literal: true

RSpec.describe StreamMerger::Segment do
  let(:segment) do
    StreamMerger::Segment.new(file: file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000000.ts"),
                              last_modified: Time.now)
  end

  it "calculates duration" do
    expect(segment.duration).to eq 6.33
  end

  it "calculates start" do
    expect(segment.start_time).to eq Time.parse("2024-11-01 19:51:01.198000000 UTC")
  end

  it "calculates end" do
    expect(segment.end_time).to eq segment.start_time + segment.duration.seconds
  end
end
