# frozen_string_literal: true

RSpec.describe StreamMerger::Ffmpeg::Utils do
  let(:dummy_class) { Class.new { extend StreamMerger::Ffmpeg::Utils } }
  let(:file) { file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000000.ts") }

  it "calculates duration" do
    expect(dummy_class.ffmpeg_duration(file)).to eq 6.33
  end
end
