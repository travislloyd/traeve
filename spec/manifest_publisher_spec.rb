require_relative '../bin/publish'
require "taglib"

describe 'ManifestPublisher' do
  let(:valid_manifest_path) { 'spec/fixtures/valid_manifest.json' }
  let(:valid_manifest) { JSON::parse(File.read(valid_manifest_path)) }
  let(:vol_num) { valid_manifest["volume"] }
  let(:recipient) { valid_manifest["recipient"] }
  let(:subtitle) { valid_manifest["subtitle"] }

  describe 'on initialization' do
    context 'with valid manifest file' do
      it 'parses the manifest into instance variables' do
        publisher = ManifestPublisher.new(valid_manifest_path)
        expect(publisher.volume).to eq vol_num
        expect(publisher.recipient).to eq recipient
        expect(publisher.subtitle).to eq subtitle
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
