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

  describe 'validate_source_files' do
    let(:valid_path1) { "testValidPath1" }
    let(:valid_path2) { "testValidPath2" }
    let(:invalid_path) { "testInvalidPath" }
    let(:valid_files) { [valid_path1, valid_path2]}
    let(:invalid_files) { [valid_path1, invalid_path]}

    context "when given valid files" do
      before do 
        expect(File).to receive(:exists?).with(valid_path1).and_return(true)
        expect(File).to receive(:exists?).with(valid_path2).and_return(true)
        expect(File).to receive(:readable?).with(valid_path1).and_return(true)
        expect(File).to receive(:readable?).with(valid_path2).and_return(true)
        expect(File).to receive(:writable?).with(valid_path1).and_return(true)
        expect(File).to receive(:writable?).with(valid_path2).and_return(true)
      end

      it "checks their permissions and returns" do
        Publish.validate_source_files(valid_files)
      end
    end

    context "when given an invalid file" do
      before do 
        expect(File).to receive(:exists?).with(valid_path1).and_return(true)
        expect(File).to receive(:readable?).with(valid_path1).and_return(true)
        expect(File).to receive(:writable?).with(valid_path1).and_return(true)
        expect(File).to receive(:exists?).with(invalid_path).and_return(false)
      end

      it "throws an exception" do
        expect { Publish.validate_source_files(invalid_files) }.to raise_error(Publish::SourceFileError)
      end
    end
  end

  describe 'generate_video' do
    let(:mock_transcoder) { double("transcoder") }
    let(:output_path) { "output/path" }
    let(:image_path) { "image/path" }
    let(:mp3_path) { "mp3/path" }

    before do
      allow(FFMPEG::Transcoder).to receive(:new).and_return(mock_transcoder)
    end
                                  
    context "on normal execution" do
      it "runs the transcoder" do
        expect(mock_transcoder).to receive(:run)
        Publish.generate_video(output_path, image_path, mp3_path)
      end
    end

    context "on error" do 
      before do
        allow(mock_transcoder).to receive(:run).and_raise("Error")
      end

      it "throws an Encoding Error" do
        expect { Publish.generate_video(output_path, image_path, mp3_path) }.to raise_error(Publish::EncodingError)
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
