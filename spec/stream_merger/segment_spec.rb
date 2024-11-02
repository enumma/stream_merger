# frozen_string_literal: true

RSpec.describe StreamMerger::Segment do
  let(:segment) { StreamMerger::Segment.new(file: file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000000.ts")) }

  it "calculates duration" do
    expect(segment.duration).to eq 6.33
  end
end
