# frozen_string_literal: true

RSpec.describe StreamMerger::MergerUtils do
  let(:dummy_class) { Class.new { extend StreamMerger::MergerUtils } }
  let(:instructions) do
    [{ file: file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8"), start_seconds: 0.747,
       end_seconds: 32.689077000000005 },
     { file: file_path("ZqueuFbL1FQj-2024-11-01_19-51-01.945.m3u8"), start_seconds: 0, end_seconds: 31.942077 }, { file: file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8"), start_seconds: 0.747,
                                                                                                                   end_seconds: 32.689077000000005 }]
  end

  it "foo" do
    # dummy_class.merge_streams(instructions)
  end
end
