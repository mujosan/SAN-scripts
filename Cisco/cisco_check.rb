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

class Switch

  def faults
    @faults = []
    @faults << power_faults
    @faults << module_faults
    @faults << bootflash_faults
    @faults << port_faults
    @faults << isl_faults
    @faults
  end

  def power_faults
    faults = []
    ssh("show environment power").each_line do |line|
      if line =~ /^\d/ && line =~ /DS-CAC/ && line.split.last.downcase != "ok"
        faults << "Power supply #{line.split.first} is: #{line.split.last}"
      end
      if line =~ /^[\d|X|f]/ && line =~ /DS-X|DS-1/ && line.split.last.downcase != "powered-up"
        faults << "Module #{line.split.first} is: #{line.split.last}"
      end
    end
    faults unless faults.empty?
  end

  def module_faults
    faults = []
    scount = 0
    ssh("show module").each_line do |line|
      if line =~ /FC Module/ && line.split.last != "ok"
        faults << "FC module in slot #{line.split.first} is: #{line.split.last}"
      end
      if line =~ /Supervisor/
        scount += 1
        unless line.split[4] != "active" || line.split[4] != "ha-standby"   # unless status is "active" or "ha-standby"
          faults << "Supervisor #{scount} is: #{line.split[4]}"
        end
      end
    end
    faults unless faults.empty?
  end

  def bootflash_faults
    faults = []
    ssh("show system health statistics").each_line do |line|
      smodule = line.split.last if line =~ /module/
      if line =~ /Bootflash/
        if line.split[7].to_i > 10
          faults << "Bootflash errors in module #{smodule}"
        end
      end
    end
    faults unless faults.empty?
  end

  def port_descriptions
    descriptions = {}
    ssh("show interface description").each_line do |line|
      if line =~ /^fc/
        port_id = line.split.first
        port_description = line.split(/\s{12,14}/).last.chomp.strip
        descriptions[port_id] = port_description
      end
    end
    descriptions
  end

  def port_faults
    faults = []
    descriptions = port_descriptions
    ssh("show interface brief").each_line do |line|
      if line =~ /^fc/ && line.split[1] != "4094" && line.split[4] != "up" &&
                          line.split[4] != "down" && line.split[4] != "trunking"
        faults << "Port #{line.split[0]} (#{descriptions[line.split[0]]} : #{line.split[1]})" +
                  " is #{line.split[4]}"
      end
    end
    faults unless faults.empty?
  end

  def isl_faults
    faults = []
    descriptions = port_descriptions
    ssh("show interface brief").each_line do |line|
      if line =~ /^fc/ && line.split[1] != "4094" && line.split[2] == "E" && # fc line not in isolated VSAN and it's an E_Port
                          line.split[3] != "on" && line.split[4] != "trunking"
        faults << "ISL #{line.split[0]} (#{descriptions[line.split[0]]} : #{line.split[1]})" +
                  " is #{line.split[4]}"
      end
    end
    faults unless faults.empty?
  end

end # of Switch
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
