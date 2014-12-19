#!/usr/bin/env ruby
#
# clariion_nar_collect.rb
#
# For each Clariion this script:
#   lists NAR files present in the NAR directory;
#   lists the NAR files available on the Clariion; 
#   transfers any new NAR files;
#
############### Required Files ##############
require_relative "clariion"
############### Required Gems ###############
require "optparse"
require "ostruct"
#############################################
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.clariions = ['clariion1','clariion2','vnx1','vnx2']

    option_parser = OptionParser.new do |opts|
      opts.banner = "Usage: clariion_nar_collect.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-i CLARIION", "Enter specific Clariion") do |clariion|
        options.clariions = []
        clariion = clariion.split("_").first if clariion.end_with?("_spa")
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
#############################################
################ Main Script ################
options = OptionParse.parse(ARGV)

options.clariions.each do |name|
  puts "Processing #{name.split("_").first.upcase}"
  c = Clariion.new(name)
  c.get_nars
end
#################### End ####################
