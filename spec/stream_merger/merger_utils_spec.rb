# frozen_string_literal: true

RSpec.describe StreamMerger::MergerUtils do # rubocop:disable Metrics/BlockLength
  let(:dummy_class) { Class.new { extend StreamMerger::MergerUtils } }
  let(:instructions1) do
    [{ file: file_path("ZqueuFbL1FQj-2024-11-01_19-51-01.945.m3u8"), start_seconds: 0.747,
       end_seconds: 32.689077000000005, width: 352, height: 258 }]
  end

  let(:instructions2) do
    [{ file: "./spec/fixtures/ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8", start_seconds: 0.747,
       end_seconds: 32.689077000000005, width: 258, height: 352 },
     { file: "./spec/fixtures/ZqueuFbL1FQj-2024-11-01_19-51-01.945.m3u8", start_seconds: 0, end_seconds: 31.942077,
       width: 352, height: 258 }]
  end

  let(:instructions3) do
    [
      { file: "./spec/fixtures/ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8", start_seconds: 0.747,
        end_seconds: 32.689077000000005, width: 258, height: 352 },
      { file: "./spec/fixtures/ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8", start_seconds: 0.747,
        end_seconds: 32.689077000000005, width: 258, height: 352 },
      { file: "./spec/fixtures/ZqueuFbL1FQj-2024-11-01_19-51-01.945.m3u8", start_seconds: 0, end_seconds: 31.942077,
        width: 352, height: 258 }
    ]
  end

  let(:instructions4) do
    [
      { file: "./spec/fixtures/ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8", start_seconds: 0.747,
        end_seconds: 32.689077000000005, width: 258, height: 352 },
      { file: "./spec/fixtures/ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8", start_seconds: 0.747,
        end_seconds: 32.689077000000005, width: 258, height: 352 },
      { file: "./spec/fixtures/ZqueuFbL1FQj-2024-11-01_19-51-01.945.m3u8", start_seconds: 0, end_seconds: 31.942077,
        width: 352, height: 258 },
      { file: "./spec/fixtures/ZqueuFbL1FQj-2024-11-01_19-51-01.945.m3u8", start_seconds: 0, end_seconds: 31.942077,
        width: 352, height: 258 }
    ]
  end

  xit "one participant" do
    dummy_class.merge_streams(instructions1)
  end

  xit "two participants" do
    dummy_class.merge_streams(instructions2)
  end

  it "three participants" do
    dummy_class.merge_streams(instructions3)
  end

  xit "four participants" do
    dummy_class.merge_streams(instructions4)
  end
end
