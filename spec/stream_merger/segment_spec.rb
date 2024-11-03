# frozen_string_literal: true

RSpec.describe StreamMerger::Segment do
  let(:segment) { StreamMerger::Segment.new(file: file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000000.ts")) }

  it "calculates duration" do
    expect(segment.duration).to eq 6.202011
  end

  it "calculates start" do
    expect(segment.start_time).to eq Time.parse("2024-11-01 19:51:01.198000000")
  end

  it "calculates end" do
    expect(segment.end_time).to eq segment.start_time + segment.duration.seconds
  end
end
