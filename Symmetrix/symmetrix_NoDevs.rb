#!/usr/bin/ruby -w
#
# NoDevs.rb
#
# This script reports masking database entries with no devices.
#
# Change History:
# ===============
# v0.1 - MH - First working release.

require 'rubygems'
require 'net/ssh'

frames = ['364','285','370','080']

outfile = File.new("NoDevs.txt", "w")

puts "Symmetrix"
puts "========="

frames.each do |sid|
  print "#{sid}....."
  symmaskdb = %x[symmaskdb -sid #{sid} list database -dir all]
  symmaskdb.gsub!(/\nDirector Port\s+:\s0/, 'A') # Join lines with Director details and swap port id 0 for A.
  symmaskdb.gsub!(/\nDirector Port\s+:\s1/, 'B') # Join lines with Director details and swap port id 1 for B.
  symmaskdb.gsub!(/\n^ +/, ',') # Join lines listing LUN ids.
  symmaskdb.gsub!(/,User-generated\s+/, '') # Join lines listing LUN ids.

  symmaskdb.each("\n") do |line|
    @fa = line.split.last.gsub!(/-/, '') if line =~ /Identification/
    if line =~ /Fibre/ && line =~ /None/
      outfile.puts "#{line.split[0]} is in the Symm#{sid} #{@fa} masking database but has no LUNs!"
    end
  end
  puts ".....done."
end

puts "Finished!!!"

outfile.close

exit
