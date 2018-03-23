#!/usr/bin/env ruby
require "json-schema"
require "json"
require_relative "../lib/publish_utils"

class ManifestPublisher
	SCHEMA_PATH = 'manifests/manifestSchema.json'

  InvalidManifestError = Class.new(StandardError)

  attr_reader :volume, :recipient, :subtitle

  def initialize(manifest_path)
    parse_manifest manifest_path
  end

  def publish
    puts "Starting publish workflow for volume #{@volume}"

    begin 
      files = [@side_a_mp3_path,
               @side_a_image_path,
               @side_b_mp3_path,
               @side_b_image_path]
      PublishUtils::validate_source_files files 

      PublishUtils::write_mp3_metadata @side_a_mp3_path,
                                       @volume,
                                       @recipient,
                                       :A 

      PublishUtils::write_mp3_metadata @side_b_mp3_path,
                                       @volume,
                                       @recipient,
                                       :B 

      PublishUtils::generate_video @side_a_mkv_path,
                                   @side_a_image_path,
                                   @side_a_mp3_path
      write_to_output "sideA", mkvPath: @side_a_mkv_path

      PublishUtils::generate_video @side_b_mkv_path,
                                   @side_b_image_path,
                                   @side_b_mp3_path
      write_to_output "sideB", mkvPath: @side_b_mkv_path

      @side_a_download_url,
      @side_b_download_url = PublishUtils::upload_mp3s_to_google_drive(
        @side_a_mp3_path,
        @side_b_mp3_path,
        @volume
      )

      write_to_output "sideA", downloadLink: @side_a_download_url 
      write_to_output "sideB", downloadLink: @side_b_download_url

      @side_a_stream_url,
      @side_b_stream_url = PublishUtils::upload_videos_to_youtube({
        side_a_mkv_path: @side_a_mkv_path,
        side_b_mkv_path: @side_b_mkv_path,
        side_a_download_url: @side_a_download_url,
        side_b_download_url: @side_b_download_url,
        volume: @volume,
        subtitle: @subtitle,
        recipient: @recipient,
        side_a_tracks: @side_a_tracks,
        side_b_tracks: @side_b_tracks
      })

      write_to_output "sideA", streamLink: @side_a_stream_url
      write_to_output "sideB", streamLink: @side_b_stream_url 

      if @side_a_image_path == @side_b_image_path
        images = [ @side_a_image_path ]
      else
        images = [ @side_a_image_path, @side_b_image_path ]
      end

      @post_url = PublishUtils::create_blog_post({
        vol: @volume,
        recipient: @recipient,
        subtitle: @subtitle,
        stream_link_a: @side_a_stream_url,
        download_link_a: @side_a_download_url,
        stream_link_b: @side_b_stream_url, 
        download_link_b: @side_b_download_url, 
        side_a_tracks: @side_a_tracks,
        side_b_tracks: @side_b_tracks,
        images: images
      })

      @fb_msg = PublishUtils::gen_fb_msg @volume,
                                         @recipient,
                                         @subtitle,
                                         @side_a_stream_url,
                                         @side_b_stream_url
      write_to_output "messaging", fbMsg: @fb_msg 

      @email_msg  = PublishUtils::gen_email_msg volume: @volume,
                                                recipient: @recipient,
                                                subtitle: @subtitle,
                                                post_url: @post_url,
                                                side_a_tracks: @side_a_tracks,
                                                side_b_tracks: @side_b_tracks

      write_to_output "messaging", emailMsg: @email_msg
    rescue InvalidManifestError => e
      STDERR.puts "There's an error with your manifest. The publish workflow is aborting.  See the error message below for more information.\n#{e.message}"
      exit(1)
    rescue PublishUtils::EncodingError => e
      STDERR.puts "There was an error encoding a movie file.  The publish workflow is aborting.  See the error message below for more information.\n#{e.message}"
      exit(1)
    rescue PublishUtils::ExternalDependencyError => e
      STDERR.puts "There was an error with an external dependency.  The publish workflow is aborting.  See the error message below for more information.\n#{e.message}"
      exit(1)
    rescue StandardError => e
      STDERR.puts e.message
      exit(1)
    end

    puts "Publsih workflow completed successfully!"
	end

  private 

  def parse_manifest(path)
		begin
      puts "\nParsing manifest..."
			manifest_file = File.read(path)
			@manifest = JSON::parse(manifest_file) if JSON::Validator.validate!(SCHEMA_PATH, manifest_file)
      puts "Manifest at path=#{path} parsed successfully!"
		rescue StandardError => e
      raise InvalidManifestError.new e
		end

    @volume = @manifest["volume"]
    @recipient = @manifest["recipient"] 
    @subtitle = @manifest["subtitle"]

    @side_a_mp3_path = @manifest["sideA"]["mp3Path"]
    @side_a_image_path = @manifest["sideA"]["imgPath"]
    @side_a_mkv_path = @manifest["outputDir"] + "HRv#{@volume}sideA.mkv"
    @side_a_tracks = @manifest["sideA"]["tracks"]

    @side_b_mp3_path = @manifest["sideB"]["mp3Path"]
    @side_b_image_path = @manifest["sideB"]["imgPath"]
    @side_b_mkv_path = @manifest["outputDir"] + "HRv#{@volume}sideB.mkv"
    @side_b_tracks = @manifest["sideB"]["tracks"]
	end

  def write_to_output(output_key, payload)
    @manifest["output"] ||= {} 

    if @manifest["output"][output_key]
      @manifest["output"][output_key].merge!(payload)
    else
      @manifest["output"][output_key] = payload
    end

    File.open("output/v#{@volume}.json","w") do |f|
      f.write @manifest.to_json 
    end
  end
end

if $0 == __FILE__  #Start script if it is executed directly
  	raise ArgumentError, "Usage: #{$0} path" unless ARGV.length == 1	
    publisher = ManifestPublisher.new ARGV[0]
    publisher.publish
end
