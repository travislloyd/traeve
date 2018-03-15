require_relative '../bin/publish'
require "taglib"

describe 'publish' do
  let(:valid_manifest) { JSON::parse(File.read('spec/fixtures/valid_manifest.json')) }

  describe 'parse_manifest' do
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

  describe 'write_mp3_metadata' do
    let(:valid_mp3_path) { "spec/fixtures/testmp3.mp3" }
    let(:invalid_mp3_path) { "spec/fixtures/MADE_UP_PATH.mp3" }
    let(:vol_num) { 99 }
    let(:recipient) { "testRecipient" }
    let(:side) { "Z" }
    let(:expected_artist) { "TRAEVE.COM PRESENTS" }
    let(:expected_genre) { "LUDDITE ROCK" }
    let(:expected_album) { "HARDLY RELEVANT vol. #{vol_num}" }
    let(:expected_title) { "Vol. #{vol_num}: #{recipient} -- Side #{side}" }

    context 'when file is valid' do
      before(:each){
        TagLib::MPEG::File.open(valid_mp3_path) { |file| file.strip }
      }

      it 'sets the artist, album, genre, and title tags of a file' do
        Publish.write_mp3_metadata(valid_mp3_path, vol_num, recipient, side)

        TagLib::MPEG::File.open(valid_mp3_path) do |file|
          tag = file.id3v2_tag
          expect(tag.artist).to eq expected_artist
          expect(tag.genre).to eq expected_genre
          expect(tag.album).to eq expected_album
          expect(tag.title).to eq expected_title
        end
      end
    end

    context 'when file is invalid' do
      it 'throws an invalid manifest exception' do
        expect { Publish.write_mp3_metadata(invalid_mp3_path, vol_num, recipient, side) }.to raise_error(Publish::SourceFileError)
      end
    end
  end
end
