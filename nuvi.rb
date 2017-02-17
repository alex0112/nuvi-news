#!/usr/bin/ruby
require 'httparty'
require 'nokogiri'
require 'fileutils'

uri_param = ARGV[0]
if uri_param == nil then
  uri_param = 'http://feed.omgili.com/5Rh5AMTrc4Pv/mainstream/posts/'
end


def scrape_zip_files(uri, write_dir="zip_files")
  ## Get the filenames
  puts 'Locating zip files at specified URI...'
  page_obj = Nokogiri::HTML(HTTParty.get(uri))
  filenames = page_obj.css('td a').map {|node| node['href'] }.select {|attr| attr.include? ".zip"} ## Exclude anything that doesn't end with '.zip'
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
    puts "* wrote #{write_dir}/#{name}*"
  end
end




scrape_zip_files(uri_param)
puts 'success'
