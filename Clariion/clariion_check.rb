#!/usr/local/bin/ruby -w
#--
# Copyright 2014 by Martin Horner (martin@mujosan.com)
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
require_relative 'clariion'
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.clariions = ['clariion01','clariion02','vnx01','vnx02']

    option_parser = OptionParser.new do |opts|
      opts.banner = "Usage: clariion_check.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-i CLARIION", "Enter specific Clariion") do |clariion|
        if options.clariions.include?(clariion.downcase) 
          options.clariions = []
          clariion = clariion.split("_").first if clariion.end_with?("spa")
          options.clariions << clariion
        else
          puts "Sorry, that Clariion is not on the list!"
          puts "Either you have experienced a typing malfunction or the script needs an update."
          exit
        end
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
