require_relative '../lib/youtube_client'

describe 'YoutubeClient' do
  let(:mock_service) { double("Service") }

  before do
    YoutubeClient.instance_variable_set(:@service, mock_service)
    # allow(Google::Apis::YoutubeV3::YouTubeService).to receive(:new).and_return(mock_service)
  end

  describe 'add_to_playlist' do
    let(:playlist_id) { 1 }
    let(:video_id) { 2 }
    
    context "on normal exexcution" do
      before do
        expect(mock_service).to receive(:insert_playlist_item)
      end

      it "calls the external service method" do
        YoutubeClient.add_to_playlist(playlist_id, video_id)
      end
    end

    context "on error" do
      before do
        expect(mock_service).to receive(:insert_playlist_item).and_raise(StandardError)
      end

      it "throws a Youtube error" do
        expect { YoutubeClient::add_to_playlist(playlist_id, video_id) }.to raise_error(YoutubeClient::YoutubeError)
      end
    end
  end

  describe 'create_playlist' do
    let(:title) { "test title" }
    let(:privacy_status) { "private" }
    let(:response_mock) { double("response") }
    
    context "on normal exexcution" do
      before do
        expect(response_mock).to receive(:id).and_return 99
        expect(mock_service).to receive(:insert_playlist).and_return response_mock
      end

      it "calls the external service method" do
        YoutubeClient.create_playlist(title, privacy_status)
      end
    end

    context "on error" do
      before do
        expect(mock_service).to receive(:insert_playlist).and_raise(StandardError)
      end

      it "throws a Youtube error" do
        expect { YoutubeClient::create_playlist(title, privacy_status) }.to raise_error(YoutubeClient::YoutubeError)
      end
    end
  end

  describe 'upload' do
    let(:file){ "test_file" }
    let(:title){ "test title" }
    let(:description){ "description" }
    let(:category_id){ "category id" }
    let(:keywords){ "keywords, keywords2" }
    let(:privacy_status){ "false" }
    
    context "on normal exexcution" do
      before do
        expect(mock_service).to receive(:insert_video)
      end

      it "calls the external service method" do
        YoutubeClient.upload(file, title, description, category_id, keywords, privacy_status)
      end
    end

    context "on error" do
      before do
        expect(mock_service).to receive(:insert_video).and_raise(StandardError)
      end

      it "throws a Youtube error" do
        expect { YoutubeClient::upload(file, title, description, category_id, keywords, privacy_status)}.to raise_error(YoutubeClient::YoutubeError)
      end
    end
  end
end
