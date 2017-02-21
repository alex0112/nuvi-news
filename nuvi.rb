#!/usr/bin/ruby
require 'httparty'
require 'nokogiri'
require 'fileutils'
require 'zip'
require 'redis'

uri_param = ARGV[0]
if uri_param == nil then
  uri_param = 'http://feed.omgili.com/5Rh5AMTrc4Pv/mainstream/posts/'
end

Zip.on_exists_proc = true ## When extracting zip files, old files will be overwritten.


def scrape_zip_files(uri, write_dir="tmp")
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

def push_xml_to_redis_list(read_dir="xml", redis_list="NEWS_XML")
  redis = Redis.new()
  file_list = Dir.foreach("#{read_dir}").drop(2) ## .drop(2) because the first two elements are . and ..
  file_list.each do |filename|
    file_data = File.read(File.join(read_dir, filename))
    redis.rpush(redis_list, {filename => file_data}.to_json) ## Save each file in the list as json
  end
end


## Where the magic happens:
scrape_zip_files(uri_param)
extract_zip()
push_xml_to_redis_list()

puts 'success'
puts '(whew!)'
