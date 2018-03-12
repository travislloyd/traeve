require_relative '../bin/publish'

describe 'parse_manifest' do
  let(:valid_manifest) { JSON::parse(File.read('spec/fixtures/valid_manifest.json')) }
  
  context 'with valid manifest file' do
    it 'returns a json object representation of the manifest' do
      output = Publish.parse_manifest('spec/fixtures/valid_manifest.json')
      expect(output).to eq valid_manifest 
    end
  end

  context "with manifest file that doesn't match schema" do
    it 'raises an InvalidManifestError' do
      expect { Publish.parse_manifest('spec/fixtures/invalid_manifest.json') }.to raise_error(Publish::InvalidManifestError)
    end
  end

  context "with manifest file that can't be read" do
    it 'raises an InvalidManifestError' do
      expect { Publish.parse_manifest('spec/fixtures/I_DONT_EXIST') }.to raise_error(Publish::InvalidManifestError)
    end
  end
end
