# frozen_string_literal: true

RSpec.describe StreamMerger::MergerUtils do
  let(:dummy_class) { Class.new { extend StreamMerger::MergerUtils } }
  let(:manifest1) { file_path("ewbmlXE8Py7L-2024-11-01_19-51-01.198.m3u8") }
  let(:manifest2) { file_path("ZqueuFbL1FQj-2024-11-01_19-51-01.945.m3u8") }

  it "foo" do
    dummy_class.merge_streams([manifest1, manifest2])
  end
end
