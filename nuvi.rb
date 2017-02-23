#!/usr/bin/ruby
require 'httparty'
require 'nokogiri'
require 'fileutils'
require 'zip'
require 'redis'

Zip.on_exists_proc = true ## When extracting zip files, old files will be overwritten.


class Scraper
  attr_accessor :uri
  
  def initialize(uri="http://feed.omgili.com/5Rh5AMTrc4Pv/mainstream/posts/", write_dir="tmp")
    ## Get the filenames
    puts 'Locating zip files at specified URI...'
    page_obj = Nokogiri::HTML(HTTParty.get(uri))
    filenames = page_obj.css('td a').map {|node| node['href'] }.select {|attr| attr.include? ".zip"} ## Exclude anything that doesn't end with '.zip'
    filenames = filenames[0..1]
    zip_uris = filenames.map {|filename| uri + filename}
    filenames_to_uris = [filenames, zip_uris].transpose.to_h
    puts 'Located.'

    ## Download the files
    puts "Downloading files to #{write_dir}..."
    puts "(This may take a moment)"
    Dir.mkdir(write_dir) if !Dir.exists? write_dir
    filenames_to_uris.each do |name, uri|
      zip_data = HTTParty.get(uri).body
      File.write("#{write_dir}/#{name}", zip_data)
      puts "* wrote #{write_dir}/#{name} *"
    end
  end

  def extract_zip(read_dir="tmp", write_dir="xml")
    Dir.mkdir(write_dir) if !Dir.exists? write_dir
    Dir.foreach(read_dir).drop(2).each do |filename| ## .drop(2) because the first two elements are . and ..
      puts "Extracting #{filename}"
      file_path = File.join(read_dir, filename)
      puts "Current file path: #{file_path}"
      Zip::File.open(file_path) do |zipped_files|
        puts "opening zip file #{zipped_files}"
        zipped_files.each do |file|
          puts "extracting #{file.name}"
          file.extract(File.join(write_dir, file.name))
        end
      end
      puts 'Done!'
    end 
  end

  def push_xml_to_redis(read_dir="xml", redis_key="NEWS_XML")
    redis = Redis.new()
    file_list = Dir.foreach("#{read_dir}").drop(2) ## .drop(2) because the first two elements are . and ..
    file_list.each do |filename|
      file_data = File.read(File.join(read_dir, filename))
      redis.hset(redis_key, filename, file_data)
    end
  end
end

## Where the magic happens:
s = Scraper.new()
s.extract_zip()
s.push_xml_to_redis()

puts 'success'
puts '(whew!)'
