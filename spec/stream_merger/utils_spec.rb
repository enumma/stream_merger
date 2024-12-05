# frozen_string_literal: true

RSpec.describe StreamMerger::Utils do
  let(:dummy_class) { Class.new { extend StreamMerger::Utils } }
  let(:file) { file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198000000000.ts") }

  it "calculates duration" do
    expect(dummy_class.ffmpeg_exact_duration(file)).to eq 6.333011
  end

  it "calculates exact duration" do
    expect(dummy_class.ffmpeg_exact_duration(file)).to eq 6.333011
  end

  it "returns data" do
    expect(dummy_class.ffmpeg_data(file)).to eq({ bitrate: "1175 kb/s", duration: 6.33, start: 0.0 })
  end

  it "calculates timestamp" do
    expect(dummy_class.file_timestamp(file)).to eq Time.parse("2024-11-01 19:51:01.198000000 UTC")
  end
end
