#!/usr/bin/ruby

require 'httparty'
require 'nokogiri'





def scrape_zip_files(url) ## Returns array of urls to zip files
  page_obj = Nokogiri::HTML(HTTParty.get(url))
  filenames = page_obj.css('td a').map {|node| node['href'] }.select {|attr| attr.include? ".zip"}
  zip_urls = filenames.map {|filename| url + filename }
end

def 



## Where the magic happens:
zip_file_urls = scrape_zip_files("http://feed.omgili.com/5Rh5AMTrc4Pv/mainstream/posts/")
