#!/usr/bin/env ruby

# 15/7/16 Friday
# Author: Jin-Yeow J Puah.
#
# Given a list of UNSW Courses this script checks if they are
# available in Semester 2.
# Not particularly fast.
#

require 'nokogiri'
require 'open-uri'

base = 'http://timetable.unsw.edu.au/2016/'

ARGF.each_line do |comp|
  url = "#{base}#{comp.strip}.html"
  begin
    page = Nokogiri::HTML(open(url))
    puts comp.strip.to_s if page.text =~ /T2/
  rescue OpenURI::HTTPError
    next
  end
end
