require "taglib"
require "streamio-ffmpeg"
require "google_drive"
require_relative 'youtube_client'

module PublishUtils
  BLOG_POST_DIR = "_posts"
  BLOG_IMG_DIR = "img/hardlyrelevant"
  GOOGLE_API_CONFIG = "config/google.json"
  GOOGLE_API_SCOPE = [
    'https://www.googleapis.com/auth/drive',
    'https://spreadsheets.google.com/feeds/',
  ]
  MP3_ARTIST_TAG = "TRAEVE.COM PRESENTS"
  MP3_ALBUM_TAG = "HARDLY RELEVANT vol."
  MP3_GENRE_TAG = "LUDDITE ROCK"
  GOOGLE_DRIVE_FOLDER = "HARDLYRELEVANT"
  PLAYLIST_PRIVACY = "private"

  SourceFileError = Class.new(StandardError)
  EncodingError = Class.new(StandardError)
  ExternalDependencyError = Class.new(StandardError)

  def self.validate_source_files(files)
    puts "\nValidating source files"

    files.each do |file|
      unless File.exists?(file) && File.readable?(file) && File.writable?(file) 
        raise SourceFileError.new "Error with file at path=#{file}.  Please verify that this file exists and public read and write permissions have been granted."
      end
    end

    puts "Source files are valid!"
  end

  def self.write_mp3_metadata(path, volume, recipient, side)
    puts "\nWriting Side #{side} MP3 metadata..."

    begin
      TagLib::MPEG::File.open(path) do |file|
        tag = file.id3v2_tag

        tag.artist = MP3_ARTIST_TAG
        tag.album = "#{MP3_ALBUM_TAG} #{volume}"
        tag.genre = MP3_GENRE_TAG
        tag.title = "Vol. #{volume}: #{recipient} -- Side #{side}"

        file.save
      end  # File is automatically closed at block end
    rescue StandardError => e
      raise SourceFileError.new e
    end

    puts "Side #{side} MP3 metadata written successfully!"
	end

  def self.generate_video(output_path, image_path, mp3_path)
    puts "\nGenerating .mkv at path #{output_path}...."
    
    begin
    # Adapted from the following ffmpeg command line command:
    # ffmpeg -loop 1 -framerate 2 -i cover_small.jpeg -i sideB.mp3 -c:v libx264 -preset fast -tune stillimage -crf 18 -c:a copy -shortest -pix_fmt yuv420p HRv10sideB.mkv
      transcoder = FFMPEG::Transcoder.new(
        '',                         # Input movie file, none in our case
        output_path,                # Output file path
        {                           # Encoding options 
          custom: [
            '-shortest',     # Stop encoding when shortest stream is done,
            '-pix_fmt',      # Set pixel format to yuv420p 
            'yuv420p',       
            '-crf',          # Set Constant Rate Factor to 18 (mid quality) 
            '18',
            '-tune',         # Optimize for still image encoding,
            'stillimage'
          ],
          audio_codec: "copy",      # Copy audio stream
          x264_preset: "fast",      # Fast encoding
          video_codec: "libx264"    # Encode video with libx264
        }, 
        {                           # Transcoder options 
          input: mp3_path,          # Pass audio as input
          input_options: { 
            loop: '1',              # Loop image for length of audio
            framerate: '2',         # Set framerate to 2
            i: image_path           # Pass cover image as input
          }
        }
      )

      transcoder.run() 
    rescue StandardError => e
      raise EncodingError.new e
    end
    
    puts "Mkv created successfully at path=#{output_path}"
	end

  def self.upload_mp3s_to_google_drive(mp3_path_A, mp3_path_B, volume)
    puts "\nUploading MP3s to Google Drive..."

    begin
      # Creates a session. This will prompt the credential via command line for the
      # first time and save it to the GOOGLE_API_CONFIG file for later usages.
      # See this document to learn how to create config.json:
      # https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md
      session = GoogleDrive::Session.from_config GOOGLE_API_CONFIG,
                                                 scope: GOOGLE_API_SCOPE

      # Create folders
      hr_folder = session.collection_by_title GOOGLE_DRIVE_FOLDER
      volume_folder = hr_folder.subcollection_by_title "v#{volume}"
      unless volume_folder
        puts "Creating v#{volume} folder..."
        volume_folder = hr_folder.create_subcollection "v#{volume}"  
      end
      
      # Upload files
      puts "Uploading Side A mp3..."
      side_a_file = volume_folder.upload_from_file(
        mp3_path_A,
        File.basename(mp3_path_A),
        convert: false
      )

      puts "Uploading Side B mp3..."
      side_b_file = volume_folder.upload_from_file(
        mp3_path_B,
        File.basename(mp3_path_B),
        convert: false
      )

      # Set public read permissions so download links work
      puts "Setting Side A permissions..."
      side_a_file.acl.push type: "anyone", 
                           allow_file_discovery: false,
                           role: "reader"

      puts "Setting Side B permissions..."
      side_b_file.acl.push type: "anyone",
                           allow_file_discovery: false,
                           role: "reader"
    rescue StandardError => e
      raise ExternalDependencyError.new e
    end

    puts "MP3s uploaded to Google Drive successfully!"
    return side_a_file.human_url, side_b_file.human_url
	end
  
  def self.upload_videos_to_youtube(side_a_mkv_path:,
                                    side_b_mkv_path:,
                                    side_a_download_url:,
                                    side_b_download_url:,
                                    volume:,
                                    subtitle:,
                                    recipient:,
                                    side_a_tracks:,
                                    side_b_tracks:)
    begin
      puts "\nUploading Videos to Youtube..."

      puts "\nCreating playlist..."
      playlist_id = YoutubeClient::create_playlist "Hardly Relevant Vol.#{volume}", PLAYLIST_PRIVACY
      puts "Playlist with id=#{playlist_id} created successfully!"
      puts 

      side_a_id = upload_to_youtube path: side_a_mkv_path,
                                    vol: volume,
                                    subtitle: subtitle,
                                    recipient: recipient,
                                    side: "A",
                                    dl_link: side_a_download_url,
                                    tracks: side_a_tracks

      side_b_id = upload_to_youtube path: side_b_mkv_path,
                                    vol: volume,
                                    subtitle: subtitle,
                                    recipient: recipient,
                                    side: "B",
                                    dl_link: side_b_download_url,
                                    tracks: side_b_tracks

      puts "\nAdding Side A to playlist..."
      YoutubeClient::add_to_playlist playlist_id, side_a_id
      puts "Successfully added Side A to playlist!"

      puts "Adding Side B to playlist..."
      YoutubeClient::add_to_playlist playlist_id, side_b_id
      puts "Successfully added Side B to playlist!"

      puts "\nVideos uploaded to Youtube successfully!"
    rescue YoutubeClient::YoutubeError => e
      raise ExternalDependencyError.new e
    end
    return "https://youtu.be/#{side_a_id}", "https://youtu.be/#{side_b_id}"
  end

  def self.upload_to_youtube(path:, vol:, subtitle:, recipient:, side:, dl_link:, tracks:)
    track_string = tracks.reduce("") do |memo, track|
      memo + "\n#{track["title"]} -- #{track["artist"]}"
    end

    description_string = "Hardly Relevant (http://traeve.com/hardlyrelevant)\n" +
                         "Volume #{vol} (#{daterange_string_from_vol(vol)})\n"+
                         "( #{subtitle} )\n" +
                         "For #{recipient}\n" +
                         "Side #{side}\n" +
                         "\n" +
                         "Download link: #{dl_link}\n" +
                         "\n" +
                         "Track Listing:\n" +
                         track_string
    title_string = "Hardly Relevant Vol.#{vol}: For #{recipient} (Side #{side})"

    puts "Uploading #{title_string}...."
    response = YoutubeClient::upload path,
                                     title_string,
                                     description_string,
                                     10, # music
                                     "Hardly Relevant",
                                     "private"
    puts "#{title_string} successfuly uploaded with ID=#{response.id}!"

    return response.id
	end

  def self.daterange_string_from_vol(vol_num)
    # Project started on New Years, so start_date for a given volume can be found by adding 7 days * the number of volumes that have elapsed
    start_date = Date.new(Time.now().year) + ( (vol_num.to_i - 1) * 7 )
    end_date = start_date + 6
    
    # Title dates are of format: "M/D/YY"
    title_date_format = "%-m/%-d/%y"
    "#{start_date.strftime(title_date_format)} - #{end_date.strftime(title_date_format)}"
  end

  def self.create_blog_post(vol:,
                            recipient:,
                            subtitle:,
                            stream_link_a:,
                            stream_link_b:,
                            download_link_a:, 
                            download_link_b:,
                            images:,
                            side_a_tracks:,
                            side_b_tracks:)
    puts "\nCreating blog post..."

    # Create directory for post images
    blog_img_base_path = "#{BLOG_IMG_DIR}/v#{vol}"
    FileUtils.mkdir_p(blog_img_base_path)

    # Copy images to new directory
    blog_img_paths = images.map do |img|
      FileUtils.cp(img, blog_img_base_path)
      blog_img_path = File.basename img
    end

    # Filename dates are of format: "2018-03-11"
    filename_date_format = "%Y-%m-%d"
    post_path = "#{BLOG_POST_DIR}/#{Time.now.strftime(filename_date_format)}-v#{vol}.md"

    puts "Creating blog post at #{post_path}"
    File.open(post_path, "w") do |file|
      file.puts "---"
      file.puts "title: \"volume #{vol} (#{daterange_string_from_vol(vol)}): for #{recipient.downcase}\""
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

    puts "Blog post successfully created!"
    return "http://traeve.com/hardlyrelevant/v#{vol}.html"
	end

  def self.gen_fb_msg(volume, recipient, subtitle, stream_a, stream_b)
    puts "\nGenerting fb message..."
    msg = "\n<INSERT CUSTOM TEXT HERE>\n\n" +
    "hardly relevant vol.#{volume}: for #{recipient}\n" +
    "( #{subtitle} )\n" +
    "side a: #{stream_a}\n" +
    "side b: #{stream_b}\n" 
    puts msg
    puts "\nDone Generting fb message..."
    return msg
  end

  def self.gen_email_msg(volume:, recipient:, subtitle:, post_url:, side_a_tracks:, side_b_tracks:)
    puts "\nGenerting email message..."
    msg = "\n<INSERT CUSTOM TEXT HERE>\n\n" +
    "t\n\n" +
    "~~~\n\n" +
    "Hardly Relevant: Volume #{volume} ( #{daterange_string_from_vol(volume)} )\n" +
    "<#{post_url}>\n" +
    "\"#{subtitle}\"\n" +
    "For #{recipient}\n\n" + 
    "Side A:\n" +
    side_a_tracks.reduce("") { |memo, track| memo + "#{track["title"]} -- #{track["artist"]}\n" } + 
    "\nSide B:\n" +
    side_b_tracks.reduce("") { |memo, track| memo + "#{track["title"]} -- #{track["artist"]}\n" } 
    puts msg
    puts "\nDone Generting email message..."
    return msg
  end
end
