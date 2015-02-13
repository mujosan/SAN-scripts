#!/usr/bin/env ruby
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