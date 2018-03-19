#!/usr/bin/env ruby

# Sample Ruby code for user authorization
require 'rubygems'
gem 'google-api-client', '>0.7'
require 'google/apis'
require 'google/apis/youtube_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'fileutils'
require 'json'

class YoutubeError < StandardError
end

# REPLACE WITH VALID REDIRECT_URI FOR YOUR CLIENT
REDIRECT_URI = 'urn:ietf:wg:oauth:2.0:oob'
APPLICATION_NAME = 'YouTube Data API Ruby Tests'

# REPLACE WITH NAME/LOCATION OF YOUR client_secrets.json FILE
CLIENT_SECRETS_PATH = 'config/youtube_secret.json'

# REPLACE FINAL ARGUMENT WITH FILE WHERE CREDENTIALS WILL BE STORED
CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                             "youtube-quickstart-ruby-credentials.yaml")

# SCOPE FOR WHICH THIS SCRIPT REQUESTS AUTHORIZATION
SCOPE = "https://www.googleapis.com/auth/youtube"

def authorize
  FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

  client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(
    client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: REDIRECT_URI)
    puts "Open the following URL in the browser and enter the " +
         "resulting code after authorization"
    puts url
    code = $stdin.gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: REDIRECT_URI)
  end
  credentials
end

def service
  return @service if @service

  # Initialize the API
  @service = Google::Apis::YoutubeV3::YouTubeService.new
  service.client_options.application_name = APPLICATION_NAME
  service.authorization = authorize

  return @service
end

def add_to_playlist(playlist_id, video_id)
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

    service.insert_playlist_item 'snippet', 
                                 body,
                                 {}
  rescue StandardError => e
    puts e.message
    raise YoutubeError.new e
  end
end

def create_playlist(title, privacy_status)
  begin
    body = {
      :snippet => {
        :title => title,
      },
      :status => {
        :privacy_status => privacy_status
      }
    }

    response = service.insert_playlist 'snippet,status', 
                                       body,
                                       {}
    
    return response.id
  rescue StandardError => e
    puts e.message
    raise YoutubeError.new e
  end
end

def upload(file, title, description, category_id, keywords, privacy_status)
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

    response = service.insert_video 'snippet,status', 
                                    body,
                                    upload_source: file
    
    return response
  rescue StandardError => e
    puts e.message
    raise YoutubeError.new e
  end
end
