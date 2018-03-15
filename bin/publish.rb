#!/usr/bin/env ruby
require "json-schema"
require "json"
require "taglib"

module Publish
	SCHEMA_PATH = 'manifests/manifestSchema.json'

	class InvalidManifestError < StandardError
	end

	class SourceFileError < StandardError
	end

  def self.parse_manifest(path)
		begin
			manifest = File.read(path)
			return JSON::parse(manifest) if JSON::Validator.validate!(SCHEMA_PATH, manifest)
		rescue Exception => e
      raise InvalidManifestError.new e
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
    rescue Exception => e
      raise SourceFileError.new e
    end
	end

	def generate_mkvs
		# not yet implemented
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
    puts "Starting publish workflow..."

    begin 
      puts "Parsing manifest..."
      manifest = parse_manifest manifest_path
      puts "Manifest parsed successfully!"

      puts "Writing Side A MP3 metadata..."
      write_mp3_metadata manifest["sideA"]["mp3Path"], manifest["volume"], manifest["recipient"], :A 
      puts "Side A MP3 metadata written successfully!"

      puts "Writing Side B MP3 metadata..."
      write_mp3_metadata manifest["sideB"]["mp3Path"], manifest["volume"], manifest["recipient"], :B 
      puts "Side B MP3 metadata written successfully!"

      #TODO validate presence of source files (mp3, images...) as a part of parse manifest
#      generate_mkvs
#      upload_to_google_drive
#      upload_to_youtube
#      create_jekyll_post
#      send_tinyletter_email
#      post_to_facebook

      return puts "Success!"
    rescue InvalidManifestError => e
      STDERR.puts "There's an error with your manifest. The publish workflow is aborting.  See the error message below for more information.\n#{e.message}"
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
