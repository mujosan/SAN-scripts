#!/usr/bin/env ruby
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
############### Required Gems ###############
require_relative "switch"
require "optparse"
require "ostruct"
#############################################
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.switch = ['cis01','cis02','cis03','cis04']

    option_parser = OptionParser.new do |opts|
      opts.banner = "Usage: cisco_check.rb [options]"
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
