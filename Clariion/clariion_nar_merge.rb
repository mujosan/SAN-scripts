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
# narmerge.rb
#
# This script generates weekly merged archive dumps from the NAR files.
#

############### Required Gems ###############
require 'date'
#############################################
############ Variable Definitions ###########
# Create an hash to store the Clariion names and associated serial numbers
clariions = {'clar01' => 'CK200033001234',
             'clar02' => 'CK200033304567',
             'clar03' => 'CK200033709876'}

#############################################
############ Constant Definitions ###########
NARDIR = "/appl/nar/"
NAVISECCLI = "/opt/Navisphere/bin/naviseccli"
OPTIONS = "-join -header n -overwrite y"
OBJECTS_W = "s,rg,l"
OBJECTS_M = "l"
FORMAT_W = "pt,on,u,tt,tb,rt,dp,ql"
FORMAT_M = "pt,on,u,tt,tb,rt,ql"
#############################################
######### Class/Module Definitions ##########
class Clariion

  def initialize(name,serialno)
    @name = name 
    @year = Date.today.year
    @nar_stored = []
    @nar_merged = []
    Dir.chdir(NARDIR)
    Dir.glob(NARDIR + serialno + '*.nar').each do |line|
      @nar_stored << line.split("/").last
    end
    Dir.glob(NARDIR + name + '*.csv').each do |line|
      @nar_merged << line.split("/").last
    end
  end # of initialize

  def mondays
    mondays = []
    firstDayOfLastYear = Date.new(Date.today.year.to_i - 1, 1, 1)
    firstMondayOfLastYear = firstDayOfLastYear - (firstDayOfLastYear.wday - 1)  # Calculate first Monday of previous year 
    0.upto(104) do |i|
      if firstMondayOfLastYear + (i * 7) < Date.today
        mondays << firstMondayOfLastYear + (i * 7)  # Return the Mondays for last year & this year in array.
      end
    end
    mondays
  end
  
  def to_nardate(date)
    datestring = date.to_s
    year, month, day = datestring.split('-')
    "#{month}/#{day}/#{year}"
  end
  
  def merge_nars
    narlist = @nar_stored.sort.to_s.gsub(/\s*\"/, '')[1..-2]
    mondays.each do |monday|
      if @nar_stored.sort[0].split("_")[2] < monday.to_s             # If date stamp on first NAR file is before current Monday
        weekoutfile = @name + "_we" + (monday + 6).strftime("%d%m%Y") + "_merged.csv"
        unless @nar_merged.include?(weekoutfile)                     # If one desn't already exist dump an archive of SP/RG data for the week
          print "Creating weekly merge file #{weekoutfile}..."
          start = to_nardate(monday) + " 00:00:01"                          # Set start time for archive dump
          finish = to_nardate(monday + 6) + " 23:59:59"                   # Set finish time of archive dump to 6 days after Monday (i.e. Sunday)
          %x[#{NAVISECCLI} analyzer -archivedump -data #{narlist} -out #{weekoutfile} #{OPTIONS} -object #{OBJECTS_W} -format #{FORMAT_W} -stime "#{start}" -ftime "#{finish}"]
          puts "done."
        end
        monthoutfile = @name + "_" + monday.strftime("%b") + "_"+ monday.year.to_s + "_merged.csv"
        unless @nar_merged.include?(monthoutfile)  # If one doesn't already exist dump an archive of LUN data for the month
          print "Creating monthly merge file #{monthoutfile}..."
          start = "%02d" % monday.month.to_s + "/01/" + monday.year.to_s + " 00:00:01"                               # Set start time for archive dump
          finish = "%02d" % monday.month.to_s + "/" + Date.civil(monday.year, monday.month, -1).day.to_s + "/" + monday.year.to_s + " 23:59:59"
          %x[#{NAVISECCLI} analyzer -archivedump -data #{narlist} -out #{monthoutfile} #{OPTIONS} -object #{OBJECTS_M} -format #{FORMAT_M} -stime "#{start}" -ftime "#{finish}"]
          puts "done."
        end
      end
    end
  end # of merge_nars

end
#############################################
################ Main Script ################
clariions.each_pair do |name, serialno|
  puts "Processing #{name.split("_").first.upcase}"
  c = Clariion.new(name,serialno)
  c.merge_nars
end
#################### End ####################

