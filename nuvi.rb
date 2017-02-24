#!/usr/bin/ruby
require 'httparty'
require 'nokogiri'
require 'fileutils'
require 'zip'
require 'redis'

Zip.on_exists_proc = true ## When extracting zip files, old files will be overwritten.


class Scraper
  attr_accessor :uri
  attr_accessor :xml_dir
  attr_accessor :zip_dir
  attr_accessor :redis_key
  
  
  def initialize(uri: "http://feed.omgili.com/5Rh5AMTrc4Pv/mainstream/posts/", zip_dir: "tmp", xml_dir: "xml", redis_key: "NEWS_XML", limit: nil)
    ## Set some vars
    @uri = uri
    @zip_dir = zip_dir
    @xml_dir = xml_dir
    @redis_key = redis_key
    @limit = limit

    ## Get the filenames
    puts 'Locating zip files at specified URI...'
    begin
    page_obj = Nokogiri::HTML(HTTParty.get(uri))
    rescue HTTParty::Error
      puts "Error connecting to #{uri}. It may be that your connection is down, or that the address is bad."
      puts "Exiting..."
      exit
    rescue StandardError
      puts "Error connecting to #{uri}. It may be that your connection is down, or that the address is bad."
      puts "Exiting..."
      exit
    end

    filenames = page_obj.css('td a').map {|node| node['href'] }.select {|attr| attr.include? ".zip"} ## Exclude anything that doesn't end with '.zip'
    filenames = filenames[0..limit-1] if limit.is_a?(Integer) && limit-1 >= 0
    zip_uris = filenames.map {|filename| uri + filename}
    filenames_to_uris = [filenames, zip_uris].transpose.to_h
    puts 'Located.'

    ## Download the files
    puts "Downloading files to #{zip_dir}..."
    puts "(This may take a moment)"
    Dir.mkdir(zip_dir) if !Dir.exist? zip_dir
    filenames_to_uris.each do |name, uri|
      zip_data = HTTParty.get(uri).body
      File.write("#{zip_dir}/#{name}", zip_data)
      puts "* wrote #{zip_dir}/#{name} *"
    end
  end

  def extract_zip()
    Dir.mkdir(self.xml_dir) if !Dir.exists? self.xml_dir
    Dir.foreach(self.zip_dir).drop(2).each do |filename| ## .drop(2) because the first two elements are . and ..
      puts "Extracting #{filename}"
      file_path = File.join(self.zip_dir, filename)
      puts "Current file path: #{file_path}"
      Zip::File.open(file_path) do |zipped_files|
        puts "opening zip file #{zipped_files}"
        zipped_files.each do |file|
          puts "extracting #{file.name}"
          file.extract(File.join(self.xml_dir, file.name))
        end
      end
      puts 'Done!'
    end 
  end

  def push_xml_to_redis()
    redis = Redis.new()
    file_list = Dir.foreach("#{self.xml_dir}").drop(2) ## .drop(2) because the first two elements are . and ..
    file_list.each do |filename|
      file_data = File.read(File.join(self.xml_dir, filename))
      redis.hset(self.redis_key, filename, file_data)
    end
  end
end

## Where the magic happens:
s = Scraper.new(limit: 1)
s.extract_zip()
s.push_xml_to_redis()

puts 'success'
puts '(whew!)'
