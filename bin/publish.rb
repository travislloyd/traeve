#!/usr/bin/env ruby
require "json-schema"
require "json"
require "taglib"
require "streamio-ffmpeg"

module Publish
	SCHEMA_PATH = 'manifests/manifestSchema.json'

	class InvalidManifestError < StandardError
	end

	class SourceFileError < StandardError
	end

	class EncodingError < StandardError
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

	def upload_to_google_drive
		# not yet implemented
	end

	def upload_to_youtube
		# not yet implemented
	end

	def create_jekyll_post
		# not yet implemented
	end

	def send_tinyletter_email
		# not yet implemented
	end

	def post_to_facebook
		# not yet implemented
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

#      upload_to_google_drive
#      upload_to_youtube
#      create_jekyll_post
#      send_tinyletter_email
#      post_to_facebook

      return puts "Success!"
    rescue InvalidManifestError => e
      STDERR.puts "There's an error with your manifest. The publish workflow is aborting.  See the error message below for more information.\n#{e.message}"
      exit(1)
    rescue EncodingError => e
      STDERR.puts "There was an error encoding a movie file.  The publish workflow is aborting.  See the error message below for more information.\n#{e.message}"
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
