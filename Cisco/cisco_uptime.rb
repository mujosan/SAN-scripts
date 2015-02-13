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
################# Required ##################
require_relative "switch"
require 'optparse'
require 'ostruct'
#############################################
############ Variable Definitions ###########
#############################################
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.switch = ['switch01','switch02',
                      'switch03','switch04']
    options.scripts = false
    options.csv = false

    option_parser = OptionParser.new do |opts|
      opts.banner = "Usage: cisco_uptime.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-i SWITCH", "Enter specific switch") do |switch|
        options.switch = []
        options.switch << switch
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
################ Main Script ################
options = OptionParse.parse(ARGV)

options.switch.each do |name|                 # Iterate through each entry in the above array.
  print "Checking #{name.upcase} system uptime - "
  c = Switch.new(name)                   # Create an instance of class Cisco for the current switch.
  puts c.uptime
end
#################### End ####################
