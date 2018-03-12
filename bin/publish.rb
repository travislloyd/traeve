#!/usr/bin/env ruby
require "json-schema"
require "json"

module Publish
	SCHEMA_PATH = 'manifests/manifestSchema.json'

	class InvalidManifestError < StandardError
	end

  def self.parse_manifest(path)
		begin
			manifest = File.read(path)
			return JSON::parse(manifest) if JSON::Validator.validate!(SCHEMA_PATH, manifest)
		rescue Exception => e
      raise InvalidManifestError.new e
		end
	end

	def set_mp3_metadata
		puts "Script starting.  Before editing tags:"
		result = system 'id3v2 -l fake'
		puts result

		system 'id3v2 --artist "TRAEVE.COM PRESENTS" \
					  --album "HARDLY RELEVANT vol. 10" \
					  --genre "LUDDITE ROCK" \
					  --song "Vol 10: Lara -- Side A+B" \
					  sidea+b.mp3'

		puts "After editing tags:"
		system 'id3v2 -l sidea+b.mp3' #=> true (prints 'hi')
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

#      set_mp3_metadata
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
