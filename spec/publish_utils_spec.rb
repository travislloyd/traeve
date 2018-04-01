require_relative '../lib/publish_utils'

describe 'PublishUtils' do
  let(:vol_num) { "00" }
  let(:recipient) { "testRecipient" }
  let(:subtitle) { "test subtitle" }
  let(:invalid_path) { "testInvalidPath" }
  let(:valid_path1) { "testValidPath1" }
  let(:valid_path2) { "testValidPath2" }
  let(:valid_files) { [valid_path1, valid_path2]}
  let(:invalid_files) { [valid_path1, invalid_path]}
  let(:download_link_a) { "download_link_a" }
  let(:download_link_b) { "download_link_b" }
  let(:side_a_tracks) { [ { "artist": "artist_1", "title": "title 1" },
                          { "artist": "artist 2", "title": "title 2" }] }
  let(:side_b_tracks) { [ { "artist": "artist_3", "title": "title 3" },
                          { "artist": "artist 4", "title": "title 4" }] }

  describe 'validate_source_files' do

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
        PublishUtils::validate_source_files(valid_files)
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
        expect { PublishUtils::validate_source_files(invalid_files) }.to raise_error(PublishUtils::SourceFileError)
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
        PublishUtils::generate_video(output_path, image_path, mp3_path)
      end
    end

    context "on error" do 
      before do
        allow(mock_transcoder).to receive(:run).and_raise("Error")
      end

      it "throws an Encoding Error" do
        expect { PublishUtils::generate_video(output_path, image_path, mp3_path) }.to raise_error(PublishUtils::EncodingError)
      end
    end
  end

  describe 'write_mp3_metadata' do
    let(:valid_mp3_path) { "spec/fixtures/testmp3.mp3" }
    let(:invalid_mp3_path) { "spec/fixtures/MADE_UP_PATH.mp3" }
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
        PublishUtils::write_mp3_metadata(valid_mp3_path, vol_num, recipient, side)

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
        expect { PublishUtils.write_mp3_metadata(invalid_mp3_path, vol_num, recipient, side) }.to raise_error(PublishUtils::SourceFileError)
      end
    end
  end

  describe "create_blog_post" do
    let(:stream_link_a) { "stream link a" }
    let(:stream_link_b) { "stream_link_b" }
    let(:images) { [ "/test/img/1.jpg", "/test/img/2.jpg" ]} 

    context "when inputs are valid" do
      before do 
        expect(FileUtils).to receive(:mkdir_p)
        expect(FileUtils).to receive(:cp).twice
        expect(File).to receive(:basename).twice
        expect(File).to receive(:open)
      end

      it "creates a file containing the provided input" do
        PublishUtils::create_blog_post vol: vol_num,
                                       recipient: recipient,
                                       subtitle: subtitle,
                                       stream_link_a: stream_link_a,
                                       stream_link_b: stream_link_b,
                                       download_link_a: download_link_a,
                                       download_link_b: download_link_b,
                                       side_a_tracks: side_a_tracks,
                                       side_b_tracks: side_b_tracks,
                                       images: images
      end
    end

    context "when an error occurs" do
      before do 
        expect(FileUtils).to receive(:mkdir_p).and_raise(StandardError)
      end

      it "throws the error" do
        expect { PublishUtils::create_blog_post vol: vol_num,
                                               recipient: recipient,
                                               subtitle: subtitle,
                                               stream_link_a: stream_link_a,
                                               stream_link_b: stream_link_b,
                                               download_link_a: download_link_a,
                                               download_link_b: download_link_b,
                                               side_a_tracks: side_a_tracks,
                                               side_b_tracks: side_b_tracks,
                                               images: images
        }.to raise_error(StandardError)
      end
    end
  end

  describe 'upload_mp3s_to_google_drive' do
    let(:mock_session) { double("session") }
    let(:mock_hr_folder) { double("hr_folder") }
    let(:mock_volume_folder) { double("volume_folder") }
    let(:mock_file_1) { double("file_1") }
    let(:mock_file_2) { double("file_2") }

    context 'normal execution' do
      before do
        expect(GoogleDrive::Session).to receive(:from_config).and_return(mock_session)
        allow(mock_session).to receive(:collection_by_title).and_return mock_hr_folder
        allow(mock_volume_folder).to receive(:upload_from_file).with(valid_path1, valid_path1, hash_including(:convert => false)).and_return mock_file_1
        allow(mock_volume_folder).to receive(:upload_from_file).with(valid_path2, valid_path2, hash_including(:convert => false)).and_return mock_file_2
        allow(mock_file_1).to receive(:acl).and_return []
        allow(mock_file_2).to receive(:acl).and_return []
        allow(mock_file_1).to receive(:human_url).and_return download_link_a
        allow(mock_file_2).to receive(:human_url).and_return download_link_b
      end

      context 'when subfolder already exists' do
        before do
          allow(mock_hr_folder).to receive(:subcollection_by_title).and_return mock_volume_folder
        end

        it "uploads without creating a new subfolder" do
          link_1, link_2 = PublishUtils::upload_mp3s_to_google_drive valid_path1, valid_path2, vol_num
          expect(link_1).to eq(download_link_a)
          expect(link_2).to eq(download_link_b)
        end
      end

      context 'when subfolder does not exist' do
        before do
          allow(mock_hr_folder).to receive(:subcollection_by_title).and_return nil
          allow(mock_hr_folder).to receive(:create_subcollection).and_return mock_volume_folder
        end

        it "creates a new subfolder and then uploads to it" do
          link_1, link_2 = PublishUtils::upload_mp3s_to_google_drive valid_path1, valid_path2, vol_num
          expect(link_1).to eq(download_link_a)
          expect(link_2).to eq(download_link_b)
        end
      end
    end

    context 'on error' do
      before do
        expect(GoogleDrive::Session).to receive(:from_config).and_raise(StandardError)
      end

      it "throws an ExternalDependencyError" do
        expect { PublishUtils::upload_mp3s_to_google_drive(valid_path1, valid_path2, vol_num) }.to raise_error(PublishUtils::ExternalDependencyError)
      end
    end
  end

  describe "upload_videos_to_youtube" do
    let(:playlist_id) { 1 }
    let(:mock_response) { double("Response") }
    let(:side_a_mkv_path) { "sideA.mkv" }
    let(:side_b_mkv_path) { "sideB.mkv" }
    let(:side_a_download_path) { "sideA.dl" }
    let(:side_b_download_path) { "sideB.dl" }

    context "on success" do
      before do
        expect(YoutubeClient).to receive(:create_playlist).and_return(playlist_id)
        expect(YoutubeClient).to receive(:add_to_playlist).twice
        expect(YoutubeClient).to receive(:upload).twice.and_return(mock_response) 
        expect(mock_response).to receive(:id).exactly(4).times.and_return 2
      end

      it "calls the YoutubeClient to create playlist, add to playlist, and upload" do
        PublishUtils::upload_videos_to_youtube({
          side_a_mkv_path: side_a_mkv_path,
          side_b_mkv_path: side_b_mkv_path,
          side_a_download_url: side_a_download_path,
          side_b_download_url: side_b_download_path,
          volume: vol_num,
          subtitle: subtitle,
          recipient: recipient,
          side_a_tracks: side_a_tracks,
          side_b_tracks: side_b_tracks
        })
      end
    end

    context "on error" do
      before do
        expect(YoutubeClient).to receive(:create_playlist).and_raise(YoutubeClient::YoutubeError)
      end

      it "throws an ExternalDepedencyError" do
        expect { PublishUtils::upload_videos_to_youtube({
          side_a_mkv_path: side_a_mkv_path,
          side_b_mkv_path: side_b_mkv_path,
          side_a_download_url: side_a_download_path,
          side_b_download_url: side_b_download_path,
          volume: vol_num,
          subtitle: subtitle,
          recipient: recipient,
          side_a_tracks: side_a_tracks,
          side_b_tracks: side_b_tracks
        })}.to raise_error(PublishUtils::ExternalDependencyError)
      end
    end
  end

  describe "daterange string from vol" do
    it "returns a date of the expected format" do
      expect(PublishUtils::daterange_string_from_vol(2)).to eq("1/8/18 - 1/14/18")
    end
  end
end
