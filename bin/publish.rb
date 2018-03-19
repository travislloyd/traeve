#!/usr/bin/env ruby
require "json-schema"
require "json"
require "taglib"
require "streamio-ffmpeg"
require "google_drive"
require_relative 'youtube'

# TODO
# -- specify versions in gemfile
# -- clean up code for DRY and readablility
# -- ruby style check
module Publish
	SCHEMA_PATH = 'manifests/manifestSchema.json'
  BLOG_POST_DIR = "_posts"
  BLOG_IMG_DIR = "img/hardlyrelevant"
  GOOGLE_API_CONFIG = "config/google.json"
  GOOGLE_API_SCOPE = [
    'https://www.googleapis.com/auth/drive',
    'https://spreadsheets.google.com/feeds/',
    'https://www.googleapis.com/auth/youtube.upload'
  ]

	class InvalidManifestError < StandardError
	end

	class SourceFileError < StandardError
	end

	class EncodingError < StandardError
	end

	class ExternalDependencyError < StandardError
	end

  def self.parse_manifest(path)
		begin
			manifest = File.read(path)
			return JSON::parse(manifest) if JSON::Validator.validate!(SCHEMA_PATH, manifest)
		rescue StandardError => e
      raise InvalidManifestError.new e
		end
	end

  def self.validate_source_files(files)
    files.each do |file|
      unless File.exists?(file) && File.readable?(file) && File.writable?(file) 
        raise SourceFileError.new "Error with file at path=#{file}.  Please verify that this file exists and public read and write permissions have been granted."
      end
    end
  end

  def self.write_mp3_metadata(path, volume, recipient, side)
    puts "Opening mp3 from path = #{path}"

    begin
      TagLib::MPEG::File.open(path) do |file|
        tag = file.id3v2_tag

        tag.artist = "TRAEVE.COM PRESENTS"
        tag.album = "HARDLY RELEVANT vol. #{volume}"
        tag.genre = "LUDDITE ROCK"
        tag.title = "Vol. #{volume}: #{recipient} -- Side #{side}"

        file.save
      end  # File is automatically closed at block end
    rescue StandardError => e
      raise SourceFileError.new e
    end
	end

  def self.generate_video(output_path, image_path, mp3_path)
    # Based on the following command:
    # ffmpeg -loop 1 -framerate 2 -i cover_small.jpeg -i sideB.mp3 -c:v libx264 -preset fast -tune stillimage -crf 18 -c:a copy -shortest -pix_fmt yuv420p HRv10sideB.mkv
    begin
      transcoder = FFMPEG::Transcoder.new(
        '',                         # Input movie file, which there isn't in our case
        output_path,                # Output file path
        {                           # Encoding options 
          custom: %w(-shortest -pix_fmt yuv420p -crf 18 -tune stillimage), # Stop encoding when shortest stream is done, tune for processing still images
          audio_codec: "copy",      # Copy audio stream
          x264_preset: "fast",      # Fast encoding
          video_codec: "libx264"    # Encode video with libx264
        }, 
        { # Transcoder options 
          input: mp3_path,
          input_options: { loop: '1', framerate: '2', i: image_path}
        }
      )

      transcoder.run() 
    rescue StandardError => e
      raise EncodingError.new e
    end
	end

  def self.upload_mp3s_to_google_drive(mp3_path_A, mp3_path_B, volume)
    begin
      # Creates a session. This will prompt the credential via command line for the
      # first time and save it to the GOOGLE_API_CONFIG file for later usages.
      # See this document to learn how to create config.json:
      # https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md
      session = GoogleDrive::Session.from_config(GOOGLE_API_CONFIG, scope: GOOGLE_API_SCOPE)

      # Create folders
      hr_folder = session.collection_by_title("HARDLYRELEVANT")
      volume_folder = hr_folder.subcollection_by_title("v#{volume}")
      unless volume_folder
        puts "Creating v#{volume} folder..."
        volume_folder = hr_folder.create_subcollection("v#{volume}") 
      end
      
      # Upload files
      puts "Uploading Side A mp3..."
      side_a_file = volume_folder.upload_from_file(mp3_path_A, File.basename(mp3_path_A), convert: false)
      puts "Uploading Side B mp3..."
      side_b_file = volume_folder.upload_from_file(mp3_path_B, File.basename(mp3_path_B), convert: false)

      # Set public read permissions
      puts "Setting Side A permissions..."
      side_a_file.acl.push({type: "anyone", allow_file_discovery: false, role: "reader"})
      puts "Setting Side B permissions..."
      side_b_file.acl.push({type: "anyone", allow_file_discovery: false, role: "reader"})

      return side_a_file.human_url, side_b_file.human_url
    rescue StandardError => e
      raise ExternalDependencyError.new e
    end
	end
  
  def self.upload_videos_to_youtube(side_a_path, side_b_path, manifest)
    puts "\nCreating playlist..."
    playlist_id = create_playlist "Hardly Relevant Vol.#{manifest["volume"]}", "private"
    puts "Playlist with id=#{playlist_id} created successfully!"
    puts 

    side_a_id = upload_to_youtube path: side_a_path,
                                  vol: manifest["volume"],
                                  subtitle: manifest["subtitle"],
                                  recipient: manifest["recipient"],
                                  side: "A",
                                  dl_link: manifest["sideA"]["downloadLink"],
                                  tracks: manifest["sideA"]["tracks"]

    side_b_id = upload_to_youtube path: side_b_path,
                                  vol: manifest["volume"],
                                  subtitle: manifest["subtitle"],
                                  recipient: manifest["recipient"],
                                  side: "B",
                                  dl_link: manifest["sideB"]["downloadLink"],
                                  tracks: manifest["sideB"]["tracks"]

    puts "\nAdding Side A to playlist..."
    add_to_playlist(playlist_id, side_a_id)
    puts "Successfully added Side A to playlist!"

    puts "Adding Side B to playlist..."
    add_to_playlist(playlist_id, side_b_id)
    puts "Successfully added Side B to playlist!"

    return "https://youtu.be/#{side_a_id}", "https://youtu.be/#{side_b_id}"
  end

  def self.upload_to_youtube(path:, vol:, subtitle:, recipient:, side:, dl_link:, tracks:)
    description_string = "Hardly Relevant (http://traeve.com/hardlyrelevant)\n" +
                         "Volume #{vol} (#{daterange_string_from_vol_num(vol)})\n"+
                         "#{subtitle}\n" +
                         "For #{recipient}\n" +
                         "Side #{side}\n" +
                         "\n" +
                         "Download link: #{dl_link}\n" +
                         "\n" +
                         "Track Listing:\n" +
                         tracks.reduce("") { |memo, track| memo + "\n#{track["title"]} -- #{track["artist"]}" }
    title_string = "Hardly Relevant Vol.#{vol}: For #{recipient} (Side #{side})"

    puts "Uploading #{title_string}...."
    response = upload path,
                          title_string,
                          description_string,
                          10, # music
                          "Hardly Relevant",
                          "private"
    puts "#{title_string} successfuly uploaded with ID=#{response.id}!"

    return response.id
	end

	def send_tinyletter_email
		# not yet implemented
	end

	def post_to_facebook
		# not yet implemented
	end

  def self.daterange_string_from_vol_num(vol_num)
    # Project started on New Years, so start_date for a given volume can be found by adding 7 days * the number of volumes that have elapsed
    start_date = Date.new(Time.now().year) + ( (vol_num.to_i - 1) * 7 )
    end_date = start_date + 7
    
    # Title dates are of format: "M/D/YY"
    title_date_format = "%_m/%-d/%y"
    "#{start_date.strftime(title_date_format)} - #{end_date.strftime(title_date_format)}"
  end

  def self.create_blog_post(vol:, recipient:, subtitle:, stream_link_a:, stream_link_b:, download_link_a:, download_link_b:, images:, side_a_tracks:, side_b_tracks:)
    blog_img_base_path = "#{BLOG_IMG_DIR}/v#{vol}"
    FileUtils.mkdir_p(blog_img_base_path)

    blog_img_paths = images.map do |img|
      FileUtils.cp(img, blog_img_base_path)
      blog_img_path = File.basename img
    end

    # Filename dates are of format: "2018-03-11"
    filename_date_format = "%Y-%m-%d"
    post_path = "#{BLOG_POST_DIR}/#{Time.now.strftime(filename_date_format)}-volume-#{vol}-for-#{recipient}.md"

    puts "Creating blog post at #{post_path}"
    File.open(post_path, "w") do |file|
      file.puts "---"
      file.puts "title: \"volume #{vol} (#{daterange_string_from_vol_num(vol)}): for #{recipient.downcase}\""
      file.puts "subtitle: #{subtitle}"
      file.puts "category: hardlyrelevant"
      file.puts "volume: v#{vol}"
      file.puts "youtube-a: #{stream_link_a}"
      file.puts "download-a: #{download_link_a}"
      file.puts "youtube-b: #{stream_link_b}"
      file.puts "download-b: #{download_link_b}"
      file.puts "images:"
      blog_img_paths.each { |image_path| file.puts "- #{image_path}" }
      file.puts "layout: two-col"
      file.puts "---"
      file.puts '#### Side A ( <a target="_blank" href="{{ page.youtube-a }}">stream</a> / <a target="_blank" href="{{ page.download-a }}">download</a> ) ####'
      side_a_tracks.each_with_index { |track, ind| file.puts "#{ind}. #{track["title"]} -- #{track["artist"]}" }
      file.puts 
      file.puts '#### Side B ( <a target="_blank" href="{{ page.youtube-b }}">stream</a> / <a target="_blank" href="{{ page.download-b }}">download</a> ) ####'
      side_b_tracks.each_with_index { |track, ind| file.puts "#{ind}. #{track["title"]} -- #{track["artist"]}" }
    end
	end

  def self.publish(manifest_path)
    puts "Starting publish workflow with manifest_path=#{manifest_path}..."

    begin 
      puts "\nParsing manifest..."
      manifest = parse_manifest manifest_path
      puts "Manifest parsed successfully!"

      side_a_mp3_path = manifest["sideA"]["mp3Path"]
      side_a_image_path = manifest["sideA"]["imgPath"]
      side_b_mp3_path = manifest["sideB"]["mp3Path"]
      side_b_image_path = manifest["sideB"]["imgPath"]

      files = [ side_a_mp3_path,
                side_a_image_path,
                side_b_mp3_path,
                side_b_image_path ]
      puts "\nValidating source files"
      validate_source_files files 
      puts "Source files are valid!"

      puts "\nWriting Side A MP3 metadata..."
      write_mp3_metadata side_a_mp3_path,
                         manifest["volume"],
                         manifest["recipient"], 
                         :A 
      puts "Side A MP3 metadata written successfully!"

      puts "\nWriting Side B MP3 metadata..."
      write_mp3_metadata side_b_mp3_path,
                         manifest["volume"],
                         manifest["recipient"],
                         :B 
      puts "Side B MP3 metadata written successfully!"

      puts "\nGenerating .mkv for Side A..."
      side_a_mkv_path = manifest["outputDir"] + "HRv#{manifest["volume"]}sideA.mkv"
      generate_video side_a_mkv_path,
                     side_a_image_path,
                     side_a_mp3_path
      puts "Side A .mkv created successfully at path=#{side_a_mkv_path}"

      puts "\nGenerating .mkv for Side B..."
      side_b_mkv_path = manifest["outputDir"] + "HRv#{manifest["volume"]}sideB.mkv"
      generate_video side_b_mkv_path,
                     side_b_image_path,
                     side_b_mp3_path
      puts "Side B .mkv created successfully at path=#{side_b_mkv_path}"

      puts "\nUploading MP3s to Google Drive..."
      side_a_download_url, side_b_download_url = upload_mp3s_to_google_drive side_a_mp3_path, side_b_mp3_path, manifest["volume"]
      puts "MP3s uploaded to Google Drive successfully! Side A URL: #{side_a_download_url}, Side B URL: #{side_b_download_url}"

      puts "\nUploading Videos to Youtube..."
      test_path = "/Users/travislloyd/Desktop/notes/HARDLYRELEVANT/Tapes/v9--hannah/HRv99sideA.mkv"
      side_a_stream_url, side_b_stream_url = upload_videos_to_youtube(side_a_mkv_path, side_b_mkv_path, manifest)
      puts "\nVideos uploaded to Youtube successfully!"

      puts "\nCreating blog post..."
      images = [ side_a_image_path ]
      images.push side_b_image_path unless side_a_image_path == side_b_image_path
      create_blog_post vol: manifest["volume"],
                       recipient: manifest["recipient"],
                       subtitle: manifest["subtitle"],
                       stream_link_a: side_a_stream_url,
                       download_link_a: side_a_download_url,
                       stream_link_b: side_b_stream_url, 
                       download_link_b: side_b_download_url, 
                       side_a_tracks: manifest["sideA"]["tracks"],
                       side_b_tracks: manifest["sideB"]["tracks"],
                       images: images

      puts "Blog post successfully created!"

#      send_tinyletter_email
#      post_to_facebook

      return puts "Success!"
    rescue InvalidManifestError => e
      STDERR.puts "There's an error with your manifest. The publish workflow is aborting.  See the error message below for more information.\n#{e.message}"
      exit(1)
    rescue EncodingError => e
      STDERR.puts "There was an error encoding a movie file.  The publish workflow is aborting.  See the error message below for more information.\n#{e.message}"
      exit(1)
    rescue ExternalDependencyError => e
      STDERR.puts "There was an error with an external dependency.  The publish workflow is aborting.  See the error message below for more information.\n#{e.message}"
      exit(1)
    rescue StandardError => e
      STDERR.puts e.message
      exit(1)
    end
	end
end

if $0 == __FILE__  #Start script if it is executed directly
  	raise ArgumentError, "Usage: #{$0} path" unless ARGV.length == 1	
    Publish::publish(ARGV[0])
end
