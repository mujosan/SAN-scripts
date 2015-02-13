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
# check_cisco.rb
#
# This script accesses the Cisco switches via SSH and runs a number of "show" commands.
# The resulting output is parsed to derive the status of various parts of the switch.
# The following components are checked:
#   Power supplies;
#   Modules (blades);
#   Cross bar;
#   Boot flash;
#   Interface counters;
#   Port status;
#   ISLs.
#
# Any failures are printed to the console.
#
# Access to the switches is via SSH and IPs are derived from the /etc/hosts file.
# Be sure to add entries in /etc/hosts for the switches.
#
# Be sure to create a file called "config" in the ~/.ssh directory:
#  Host switch*
#    StrictHostKeyChecking no
#    UserKnownHostsFile=/dev/null
#
# Without the above any upgrades to a switch will break this script for that switch.
# The "Host" entry should contain a wildcard string for the switch names.
############### Required Gems ###############
require_relative "switch"
require "optparse"
require "ostruct"
#############################################
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.switch = ['switch01','switch02','switch03']

    option_parser = OptionParser.new do |opts|
      opts.banner = "Usage: cisco_check.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-i SWITCH", "Enter specific switch") do |switch|
        if options.switch.include?(switch.downcase)
          options.switch = []
          options.switch << switch
        else
          puts "Sorry, that switch is not on the list!"
          puts "Either you have fat fingers or the script needs an update."
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

options.switch.each do |switchname|
  print "Checking #{switchname.upcase}..."
  c = Switch.new(switchname)                          # Create an instance of class Cisco for the current switch.
  faults = c.faults.compact                           # Determine what is wrong.
  if faults.empty?
    puts "ok."
  else
    puts "Following issues found:"
    puts faults
  end
end
#################### End ####################
