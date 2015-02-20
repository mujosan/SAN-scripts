#!/usr/bin/env ruby

#--
# Copyright 2015 by Martin Horner (martin@mujosan.com)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#++

#
# NoDevs.rb
#
# This script reports masking database entries with no devices.
#

require 'rubygems'
require 'net/ssh'

frames = ['123','456','789']                            # Symmetrix SIDs

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