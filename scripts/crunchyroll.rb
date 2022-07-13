#!/bin/ruby

require 'fileutils'

if `which youtube-dl >/dev/null`

  ANIME_FILELIST = (ARGV[0] ? "#{Dir.pwd}/#{ARGV[0]}" : "/home/j1n/animelist.txt")

  Dir.chdir("/home/j1n/Videos/yt-dl/")
  puts "[*] Starting Crunchyroll Retrieval in #{Dir.pwd}"
  puts "    Using list from #{ANIME_FILELIST}"

  count = 0

  File.open(ANIME_FILELIST).each_line do |line|
    link,start = line.split(" ")
    name = link.split("/").last

    puts "[*] Creating folder for #{name}"
    Dir.mkdir(name) unless Dir.exists? name

    cmd = "youtube-dl --sub-lang enUS --write-sub --sub-format srt #{link}"
    cmd += " --playlist-start #{start}" if start

    puts "[*] Starting download of #{name}"
    exec(cmd)

    puts "[*] Moving files to #{name} folder"
    FileUtils.mv(Dir.glob("*.{srt,flv}"), "#{name}")
    count += 1
  end

  puts "Finished download of #{count} anime from Crunchyroll!"
else
  puts "[!!] ERROR: 'youtube-dl' not installed"
end
