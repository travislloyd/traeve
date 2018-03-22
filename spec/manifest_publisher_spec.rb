require_relative '../bin/publish'
require "taglib"

describe 'ManifestPublisher' do
  let(:valid_manifest) { JSON::parse(File.read('spec/fixtures/valid_manifest.json')) }
  let(:vol_num) { valid_manifest["volume"] }
  let(:recipient) { "testRecipient" }
  let(:subtitle) { "test subtitle" }
  let(:stream_link_a) { "stream link a" }
  let(:stream_link_b) { "stream_link_b" }
  let(:download_link_a) { "download_link_a" }
  let(:download_link_b) { "download_link_b" }
  let(:side_a_tracks) { [ { "artist": "artist_1", "title": "title 1" },
                          { "artist": "artist 2", "title": "title 2" }] }
  let(:side_b_tracks) { [ { "artist": "artist_3", "title": "title 3" },
                          { "artist": "artist 4", "title": "title 4" }] }
  let(:images) { [ "/test/img/1.jpg", "/test/img/2.jpg" ]} 
  let(:valid_path1) { "testValidPath1" }
  let(:valid_path2) { "testValidPath2" }

  describe 'on initialization' do
    context 'with valid manifest file' do
      it 'parses the manifest into instance variables' do
        publisher = ManifestPublisher.new('spec/fixtures/valid_manifest.json')
        expect(publisher.volume).to eq vol_num
      end
    end

    context "with manifest file that doesn't match schema" do
      it 'raises an InvalidManifestError' do
        expect { ManifestPublisher.new('spec/fixtures/invalid_manifest.json') }.to raise_error(ManifestPublisher::InvalidManifestError)
      end
    end

    context "with manifest file that can't be read" do
      it 'raises an InvalidManifestError' do
        expect { ManifestPublisher.new('spec/fixtures/I_DONT_EXIST') }.to raise_error(ManifestPublisher::InvalidManifestError) 
      end
    end
  end
end
