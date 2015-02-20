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
# celerra_check.rb
#
# This script connects to the EMC Celerras, via SSH, and retrieves the contents
# of a daily log file. The log file is created by a shell script on the Celerra
# that runs a "nas_checkup" command. This shell script is placed in
# /etc/cron.daily on the control station. The log file, daily.log, is created in
# the log sub-directory of the user ("script") home directory on the control 
# station.
#
# The shell script should also append the run timestamp to a run.log file in the
# same directory for diagnostic purposes.
# 

############### Required Gems ###############
require 'net/ssh'
require "optparse"
require "ostruct"
#############################################
############ Constant Definitions ###########
INDENT = "\n......"
#############################################
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.celerra = ['nas01','nas02','nas03']

    option_parser = OptionParser.new do |opts|
      opts.banner = "Usage: celerra_check.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-i CELERRA", "Enter specific switch") do |celerra|
        if options.celerra.include?(celerra.downcase)
          options.celerra = []
          options.celerra << celerra
        else
          puts "Sorry, that Celerra is not on the list!"
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

class Celerra

  def initialize(name)
    # SSH to this Celerra and download the required log files
    Net::SSH.start( name, "script", :password => 'password123' ) do |ssh|
      @daily = ssh.exec!("cat log/daily.log")
    end
  end

  def check
    faults = []
    @daily.each_line do |line|
      clean_line = line.squeeze(" .").chomp
      case
      when line =~ /Control Station/ && ( line =~ /Fail/ || line =~ /Warn/ )
        faults << clean_line
        next
      when line =~ /Data Movers/ && ( line =~ /Fail/ || line =~ /Warn/ )
        faults << clean_line
        next
      when line =~ /Storage System/ && ( line =~ /Fail/ || line =~ /Warn/ )
        faults << clean_line
        next
      end
    end
    faults unless faults.empty?
  end

end # of Celerra
#############################################
################ Main Script ################
options = OptionParse.parse(ARGV)

options.celerra.each do |name|
  print "Checking #{name.upcase}..."
  c = Celerra.new(name)
  faults = c.check.compact
  if faults.empty?
    puts "ok."
  else
    puts "Following issues found:"
    puts faults
  end
end
#################### End ####################
