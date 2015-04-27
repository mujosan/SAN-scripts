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
# cisco_license_backup.rb
#
# This script iterates through the Cisco MDS switches creating a tar file
# in the bootflash: using SSH.
# The tar file is then downloaded to a local directory on the server 
# using SCP.
#
############### Required Files ##############
require_relative 'switch'
############### Required Gems ###############
require 'optparse'
require 'ostruct'
#############################################
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.switch = ['switch01','switch02',
                      'switch03','switch04',
                      'switch05','switch06',]
    options.silent = false
    options.backupfilepath = "/usr/local/san/cisco/licenses"

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("--switch SWITCH", "Enter specific switch") do |switch|
        if options.switch.include?(switch.downcase)
          options.switch = []
          options.switch << switch
        else
          puts "Sorry, that switch is not on the list!"
          puts "Either you have fat fingers or the script needs an update."
          exit
        end
      end

      opts.on( '--silent', 'Silent operation - no console messages' ) do
        options.silent = true
      end
      
      opts.on( '--path', 'Enter license file path' ) do |licensefilepath|
        options.licensefilepath = licensefilepath
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end

    end

    opts.parse!(args)
    options
  end # of parse()

end # of OptionParse

class Switch

  def backup_licenses(licensefilepath)
    result = ssh("copy licenses bootflash:license_file.tar")
    scp("bootflash:license_file.tar", licensefilepath)
  end
  
end # of Switch

################ Main Script ################
options = OptionParse.parse(ARGV)

options.switch.each do |switchname|
  print "Backing up licenses on #{switchname.upcase}..." unless options.silent
  s = Switch.new(switchname)
  s.backup_licenses(options.licensefilepath)
  puts "done." unless options.silent
end
puts "Finished!" unless options.silent
#################### End ####################