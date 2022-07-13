#!/usr/bin/env ruby

require 'optparse'
require 'pp'

# GLOBALS
MCU          = "m2560"
BAUDRATE     = "115200"
PROGRAMMER   = "wiring"
USB          = "ttyACM0"
INCLUDE      = "/home/j1n/Dropbox/UNSW/2015 - First Year/Semester 2 - Spring/COMP2121/labs/asm/defines"

CC           = "avra"
CCFLAGS      = "-I"

LOADER       = "avrdude"
AVRDUDEFLAGS = "-c #{PROGRAMMER} -p #{MCU} -b #{BAUDRATE} -P \"/dev/#{USB}\" -U flash:w:"

# FUNCTIONS
def clean
  files = []
  files << Dir.glob("*.cof") << Dir.glob("*.obj") << Dir.glob("*.eep.hex")
  puts "[-] Deleting extra files ..." unless files.length.zero?
  pp files.flatten!
  files.each do |file|
    File.delete file
    puts "[!] Unable to delete file #{file}!" unless !File.exists? file
  end
end

def assemble asm_file
  abort "\n[!] Incorrect filetype provided for assembly!" if File.extname(asm_file) != '.asm'
  system "#{CC} #{CCFLAGS} \"#{INCLUDE}\" #{asm_file}"
end

# OPTIONS
ARGV.push "-h" if ARGV.empty?
options = {}
options[:default] = true
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [OPTIONS] [FILE]"

  opts.on("-h", "--help", "Show this message") do |h|
    options[:help] = h
    puts opts
    exit
  end

  opts.on("-l", "--load", "Loads the first hex file given to the board.") do |l| # =>
    options[:load] = l
    options[:default] = false
  end

  opts.on("-a", "--assemble", "Assembles asm files provided.") do |a|
    options[:assemble] = a
    options[:default] = false
  end
end.parse!

options[:files] ||= ARGV

# MAIN
if options[:default] == true then
  asm_file = options[:files].first
  assemble(asm_file)
  hex_file = asm_file.gsub(".asm", ".hex")
  abort "\n[!] Errors assembling file: #{asm_file}" unless File.exists? hex_file
  abort "\n[!] Device #{USB} not attached!" unless File.exist? "/dev/#{USB}"
  system "#{LOADER} #{AVRDUDEFLAGS}#{hex_file}:i -D"
  puts "\n[+] #{hex_file} successfully loaded to board!"
  clean
  exit
elsif !options[:default] then
  if options[:load] then
    file = options[:files].first
    abort "[!] Cannot find file #{file}" unless File.exists? file
    abort "[!] Device #{USB} not attached!" unless File.exist? "/dev/#{USB}"
    system "#{LOADER} #{AVRDUDEFLAGS}#{hex_file}:i -D"
    puts "[+] #{hex_file} successfully loaded to board!"
  elsif options[:assemble] then
    files = options[:files]
    files.each do |f|
      abort "Invalid filetype for assembly: #{File.extname f}" unless File.extname(f).eql? '.asm'
      assemble(f)
      clean
      puts "\n\n"
    end
  end
end
