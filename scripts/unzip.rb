#!/usr/bin/env ruby

# unzip.rb
# 14 July 2015
#
# This script matches model names from the album name of the zip file
# Then unzips the archive using p7zip (7za x [zip file] -o[folder name])
# Finally removes the zip file

puts "[*] Gathering files and album names . . ."
albums = Hash.new

Dir.glob("*.zip").each do |zip|
  name = zip.match(/[A-Za-z]+\s([A-Za-z]+\s)?([A-Za-z]+)?/)
  albums[zip] = name.to_s
end

puts "Filenames retrieved:"
p albums.values.uniq

puts "[*] Unzipping albums"
albums.each do |k, v|
  print "#{k} : #{v}..."
  IO.popen("7za x \"#{k}\" -o\"#{v}\"")
  puts "Done!"
end

puts "Total files unzipped: #{albums.size}"
puts "Total folders created: #{albums.values.uniq.size}"
