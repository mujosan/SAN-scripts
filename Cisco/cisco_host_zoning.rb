#!/usr/bin/env ruby 
#
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
############### Required Gems ###############
require "rubygems"
require 'optparse'
require 'ostruct'
require "net/ssh"
#############################################
############ Variable Definitions ###########
#############################################
############ Constant Definitions ###########
HEAD = "#########################################################"
TAIL = "#########################################################"
#############################################
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.switches = ['switch01','switch02',
                        'switch03','switch04']
    options.inactive = false

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: cisco_host_zoning.rb [options] <hostname>"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("--switch SWITCH", "Enter specific switch") do |switch|
        options.switches = []
        options.switches << switch
      end

      opts.on("-a", "--all", "All zoning inactive and active") do
        options.inactive = true
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
  attr_reader :flogi_list

  def initialize(name)
    @switchname = name
    Net::SSH.start( name, "script", :password => 'password' ) do |ssh|
      ssh.exec!("show flogi database").each_line do |line|
        @flogi_list = []
        case line
        when /^fc/
          @flogi_list << if p
          p = Port.new(line.first)
          p.vsan = line.split[1]
          p.pwwn = line.split[3]
          next
        when /\[/
          p.alias = line.delete("[]").chomp
          next
        else
        end
      end
      @zoneset_active = ssh.exec!("show zoneset active")
      @interface_description = ssh.exec!("show interface description")
    end
    @zoneset_active << "\n"
  end # of initialize
 
  def host_active?(hostname)
    true if @flogi_database.upcase =~ /#{hostname}/
  end

  def host_patched?(hostname)
    true if @interface_description.upcase =~ /#{hostname}/
  end
 
  def print_zone(hostname,vsan,zoneset,zone,members)
    puts HEAD
    puts "Host #{hostname} in Zoneset #{zoneset} (VSAN #{vsan})"
    puts "has the zone #{zone}"
    puts "with the following members:"
    members.each_pair {|hba, wwn| puts "#{hba.ljust(16)} => #{wwn}" }
  end
 
  def zoning(hostname)
    zoneset = ""
    vsan = ""
    zone = ""
    zonelist = []
    members = {}
    found = FALSE
    @zoneset_active.each_line do |line|
      case line
      when /zoneset name/
        zoneset = line.split[2]
        vsan = line.split[4]
        next
      when /zone name/
        found = FALSE
        members.clear if members.length > 0
        zone = line.split[2]
        found = TRUE if line.upcase.include?(hostname)
        next
      when /pwwn/
        if line =~ /fcid/
          members[line.split("[").last.delete("]").chomp] = line.split("[")[1].delete("]")
        else
          members[line.split.last.delete("[]").chomp] = line.split[1]
        end
        next
      else
        if found == TRUE
          print_zone(hostname,vsan,zoneset,zone,members) unless zonelist.include?(zone)
        end
        zonelist << zone unless zonelist.include?(zone)
        next
      end
    end
  end
 
  def ports(switch,host)
    flogi = @flogi_database.gsub(/\n\s+\[/, " ")               # Merge any port description lines into the previous line.
    flogi.each_line do |line|
      if line =~ /^fc/ && line.split.last.include?(host)       # If line starts with port id and contains the hostname...
        puts "#{line.split.last.delete("[]")} is logged-in to #{switch.upcase} #{line.split.first}"
      end
    end
  end # of ports

  def description(switch,host)
    @interface_description.each_line do |line|
      if line =~ /^fc/ && line.split.last.include?(host)       # If line starts with port id and contains the hostname...
        puts "#{line.split.last} is patched to #{switch.upcase} #{line.split.first}"
      end
    end
  end # of description

end # of Switch
 
#############################################
 
################ Main Script ################
options = OptionParse.parse(ARGV)

fail "Please specify hostname" unless ARGV.length > 0
hostname = ARGV[0].upcase
 
options.switches.each do |switchname|                          # Iterate through each entry in the above array.
  c = Switch.new(switchname)                            # Create an instance of class Cisco for the current switch.
  c.zoning(hostname)
  if c.host_active?(hostname)
    c.ports(switchname,hostname)
  else
    c.description(switchname,hostname)
  end
end
puts TAIL 
#################### End ####################
