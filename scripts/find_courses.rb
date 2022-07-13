#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'

# UNSW COMP Courses for 2016
BASE_URL = 'http://www.handbook.unsw.edu.au/vbook2016/brCoursesBySubjectArea.jsp?studyArea=COMP&StudyLevel=Undergraduate'.freeze

page = Nokogiri::HTML(open(BASE_URL))

# Get the rows in the table for the courses
courses = page.xpath('//table').children.css('tr')[2..78]

# Get relevant course information
list = courses.each_with_object({}) do |course, hash|
  info = course.children.css('td')
  code = info[0].children.text
  name = info[1].children.first.children.text
  link = info[1].children.first.attribute('href').value

  hash[code] = { name: name, link: link }
  hash
end

# Prerequisites
list.each do |code, value|
  p = Nokogiri::HTML(open(value[:link]))
  text = p.css('div.summary').text
  # prereqs = 'N/A'
  # prereqs = text.match(/([Pp]rereq.*)(?=(\.|Ex))/) if text =~ /[Pp]rereq\w*/

  puts "#{code}" if text =~ /3231/
end
