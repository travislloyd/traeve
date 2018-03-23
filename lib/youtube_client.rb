require 'google/apis'
require 'google/apis/youtube_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'fileutils'
require 'json'
module YoutubeClient
  REDIRECT_URI = 'urn:ietf:wg:oauth:2.0:oob' # URI provided by google for CLI apps
  APPLICATION_NAME = 'Hardly Relevant Command Line Publisher'
  CLIENT_SECRETS_PATH = 'config/youtube_secret.json'
  CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                               "hr-uploader-youtube-credentials.yaml")
  SCOPE = "https://www.googleapis.com/auth/youtube"

  YoutubeError = Class.new(StandardError)

  def self.add_to_playlist(playlist_id, video_id)
    begin
      body = {
        :snippet => {
          :playlist_id => playlist_id,
          :resource_id => {
            :kind => 'youtube#video',
            :video_id => video_id
          }
        }
      }

      # http://www.rubydoc.info/github/google/google-api-ruby-client/Google/Apis/YoutubeV3/YouTubeService#insert_playlist_item-instance_method
      service.insert_playlist_item 'snippet', # properties to write 
                                   body,      # resource
                                   {}         # optional parameters
    rescue StandardError => e
      puts e.message
      raise YoutubeError.new e
    end
  end

  def self.create_playlist(title, privacy_status)
    begin
      body = {
        :snippet => {
          :title => title,
        },
        :status => {
          :privacy_status => privacy_status
        }
      }

      # http://www.rubydoc.info/github/google/google-api-ruby-client/Google/Apis/YoutubeV3/YouTubeService#insert_playlist-instance_method
      response = service.insert_playlist 'snippet,status', # properties to write 
                                         body,             # resource
                                         {}                # optional parameters
      
      return response.id
    rescue StandardError => e
      puts e.message
      raise YoutubeError.new e
    end
  end

  def self.upload(file, title, description, category_id, keywords, privacy_status)
    begin
      body = {
        :snippet => {
          :title => title,
          :description => description,
          :tags => keywords.split(','),
          :categoryId => category_id,
        },
        :status => {
          :privacy_status => privacy_status
        }
      }

      # http://www.rubydoc.info/github/google/google-api-ruby-client/Google/Apis/YoutubeV3/YouTubeService#insert_video-instance_method
      response = service.insert_video 'snippet,status',   # properties to write 
                                      body,               # resource
                                      upload_source: file # specify upload file
      
      return response
    rescue StandardError => e
      puts e.message
      raise YoutubeError.new e
    end
  end

  private 

  def self.authorize
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

    client_id = Google::Auth::ClientId.from_file CLIENT_SECRETS_PATH
    token_store = Google::Auth::Stores::FileTokenStore.new file: CREDENTIALS_PATH
    authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
    user_id = 'default'
    credentials = authorizer.get_credentials user_id
    if credentials.nil?
      url = authorizer.get_authorization_url base_url: REDIRECT_URI
      puts "Open the following URL in the browser and enter the " +
           "resulting code after authorization"
      puts url
      code = $stdin.gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id,
        code: code,
        base_url: REDIRECT_URI
      )
    end
    credentials
  end

  def self.service
    return @service if @service

    # Initialize the API
    @service = Google::Apis::YoutubeV3::YouTubeService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize

    return @service
  end
end
