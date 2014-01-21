#!/usr/local/bin/ruby -w
#--
# Copyright 2013 by Martin Horner (martin.horner@telecom.co.nz)
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
# check_clariion.rb
#
# This script interrogates the Clariions/VNXs, via naviseccli, and queries 
# status information. Any anomalies are output to the console.
#
############### Required Gems ###############
require "optparse"
require "ostruct"
require 'timeout'
require 'time'
#############################################
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.clariions = ['clariion1','clariion2','vnx1','vnx2']

    option_parser = OptionParser.new do |opts|
      opts.banner = "Usage: clariion_check.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-i CLARIION", "Enter specific Clariion") do |clariion|
        options.clariions = []
        clariion = clariion.split("_").first if clariion.end_with?("_spa") # ignore SP id in suffix
        options.clariions << clariion
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end

    end

    option_parser.parse!(args)
    options
  end # of parse()

end # of OptionParse

class String

  def parse_trespass
    self.gsub!(/^L\w+\s\w+\s\w+\s+/, '')              # Remove LOGICAL LUN NUMBER text
    self.gsub!(/\n\w{7}\s\w+:\s+/, ',')               # Replace Default/Current O/owner text with a comma
    self.gsub!(/\nRAID Type:\s+/, ',')                # Replace RAID Type text with a comma
    self.gsub!(/^\n/, '')                             # Remove redundant newlines
  end

  def parse_disk
    self.gsub!(/\nState:\s+ /, ' State: ')
    self.gsub!(/\nBus/, 'Bus')
  end

  def parse_lun
    self.gsub!(/^L\w+\s\w+\s\w+\s+/, '')              # Remove LOGICAL LUN NUMBER text
    self.gsub!(/\nState:\s+/, ' ')
    self.gsub!(/^\n/, '')
  end

  def parse_rg
    self.gsub!(/^RaidGroup ID:\s+/, 'RaidGroup: ')   # Remove redundant text & white space
    self.gsub!(/\nRaidGroup:/, 'RaidGroup:')         # Remove newline
    self.gsub!(/\nRaidGroup State:\s+/, '~')         # Swap text for a tilde char
    self.gsub!(/\n \s+/, '~')                        # Swap newline & whitespace for a tilde char
  end
end
#############################################
################ Main Script ################
options = OptionParse.parse(ARGV)

options.clariions.each do |name|
  print "Checking #{name.split("_").first.upcase}..."
  c = Clariion.new(name)
  faults = c.faults
  if faults.empty?
    puts "ok."
  else
    puts "Following issues found:"
    puts faults
  end
end
#################### End ####################
