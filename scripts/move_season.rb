#!/bin/ruby
# move_season.rb
#
# This takes the Name of the Season and a given Directory as arguments.
# Searches for all files with in the season and creates the directory if it
# doesn't already exist. Then it moves all the relevant files to the directory.
#
# This script was created for the purpose of moving Naruto Shippuden episodes
# into folders based on season to make it easier to find episodes in order.
# Edit if necessary.

require 'fileutils'

SEASON_NAME = ARGV[0] || "The Kazekage's Rescue"
FOLDER_NAME = ARGV[1] || "Season 1 - The Kazekage's Rescue" # =>

puts Dir.pwd
puts "Season: #{SEASON_NAME}"
puts "Directory: #{FOLDER_NAME}"

Dir.mkdir(FOLDER_NAME) unless Dir.exists? FOLDER_NAME # =>
FileUtils.mv(Dir.glob("*#{SEASON_NAME} Episode*"), "#{FOLDER_NAME}")
