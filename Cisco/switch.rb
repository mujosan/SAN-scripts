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

# This file contains the class definition for SAN switches.
# For the purposes of the internal workings of this class all
# switches will be assumed to be Cisco MDS.
# Brocade? Never heard of it!
############### Required Files ##############
require_relative '../common'
############### Required Gems ###############
require "net/ssh"
#############################################
############ Variable Definitions ###########
# Create an array to store the switch names - access is via SSH and IPs are derived from the /etc/hosts file.
# The IPs for the switches (cm0*) are derived from /etc/hosts.
#
# Be sure to create a file called "config" in the ~/.ssh directory:
#  Host cm*
#    StrictHostKeyChecking no
#    UserKnownHostsFile=/dev/null
#
# Without the above any upgrades to a switch will break this script for that switch.
#############################################
############ Constant Definitions ###########
PATH = "/usr/local/tnzsan/cisco/"
INDENT = '    '
HEAD = "#########################################################"
TAIL = "#########################################################"
#############################################
class Switch

  include Common
  
  def initialize(name)
    @name = name
  end

  # This method runs a CLI command (usually a show command)
  # against the switch.
  #
  # Exception handling included for:
  #   Net::SSH::Exception - corrupted mac detected
  #
  #   This exception handling makes 10 attempts to get the running config before moving on to the next switch
  #   with a 10sec delay between attempts. This should get around the flakey behaviour of ssh due to the bug
  #   with the OpenSSH implemantation on nx-os.
  #
  def ssh(cmd)
    tries = 0
    begin
      tries += 1
      Net::SSH.start( @name, "script", :password => 'password' ) do |ssh|
        @output = ssh.exec!(cmd)
      end
      @output.chomp
    rescue Net::SSH::Exception, "corrupted mac detected"
      sleep 10
      retry if tries <= 10
    rescue Net::SSH::Exception => error
      puts "Net::SSH::Exception has occurred: #{error.inspect}"
    end
  end

  # This method backs up the switch running-config to a file.
  #
  def backup
    running_config = ssh("show running-config")
    outfile = File.open(PATH + "#{@name}_running-config_#{timestamp}.txt", 'w', 0660)
    outfile.puts running_config
    outfile.close
  end

  # This method lists the SNMP hosts.
  #
  def list_snmp
    hosts = []
    ssh("show snmp host").each_line do |line|
      hosts << line.split.first if line =~ /\./
    end
    hosts.sort!
    hosts.uniq!
    puts hosts
  end

  # This method checks for a hostname in the flogi database.
  # Therefore host is active.
  #
  def host_active?(hostname)
    ssh("show flogi database").upcase =~ /#{hostname}/
  end

  # This method checks for a hostname in the interface descriptions.
  # Therefore host is patched.
  #
  def host_patched?(hostname)
    ssh("show interface description").upcase =~ /#{hostname}/
  end

  # This method outputs info for a zone to the console.
  #
  def print_zone(hostname,vsan,zoneset,zone,members)
    puts HEAD
    puts "Host #{hostname} in Zoneset #{zoneset} (VSAN #{vsan})"
    puts "has the zone #{zone}"
    puts "with the following members:"
    members.each_pair {|hba, wwn| puts "#{hba.ljust(16)} => #{wwn}" }
  end

  # This method parses a "show zoneset active" command
  # and calls print_zone to output 
  def zoning(hostname)
    zoneset = ""
    vsan = ""
    zone = ""
    members = {}
    found = FALSE
    @zoneset_active = ssh("show zoneset active")
    @zoneset_active << "\n"
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
        print_zone(hostname,vsan,zoneset,zone,members) if found == TRUE && host_patched?(hostname)
        next
      end
    end
  end # of zoning

  # This method parses the FLOGI database and returns a hash of port ids and node ids (or WWNs)
  #
  def flogi_ports
    ports = Hash.new(0)
    ssh("show flogi database").gsub(/\n\s+\[/, " ").each_line do |line|
      if line =~ /^fc/                                                    # if line starts with port id...
        if line =~ /\]/                                                     # if line contains a device alias
          ports[line.split.first] = line.split.last.delete("[]")
        else
          ports[line.split.first] = line.split[3]
        end
      end
    end
    ports
  end # of flogi_ports

  # This method parses the interface descriptions and returns a hash of port ids & descriptions
  # Match 2 alphas followed by 4 numerics to get hostname
  #
  def descriptions
    descriptions = {}                                       # Hash to store the description for each port.
    ssh("show interface description").each_line do |line|
      if line =~ /^fc/ && line.split.last.include?(host)       # If line starts with port id and contains the hostname...
        puts "#{line.split.last} is patched to #{switch.upcase} #{line.split.first}"
      end
    end
  end # of description

  # This method parses the device aliases and returns a hash of alias names and WWNs
  #
  def device_aliases
    daliases = Hash.new(0)
    ssh("show device-alias database").each_line do |line|
      daliases[line.split[2]] = line.split.last if line =~ /^device/
    end
    daliases
  end

  # This method parses the FLOGI database and returns a hash of alias names and WWNs
  #
  def flogi_aliases
    faliases = Hash.new(0)
    ssh("show flogi database").gsub(/\n\s+\[/, " ").each_line do |line|
      if line =~ /^fc/ && line =~ /\]/                                      # if line starts with port id...
        faliases[line.split.last.delete("[]")] = line.split[3]
      end
    end
    faliases
  end # of flogi_aliases

  # This method calls the flogi_ports & device_aliases methods and outputs device alias names
  # not present in flogi_ports
  #
  def old_aliases
    @daliases = device_aliases
    @faliases = flogi_aliases
    @old_aliases = ( @faliases.to_a | @daliases.to_a ) - @faliases.to_a
    @old_aliases.sort.each do |aliasname|
      puts INDENT + "#{aliasname[0]} (#{aliasname[1]}) is not used."
    end
  end

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
        # Populate the descriptions hash where the index is equal to the port id
        # and value is the switchport description. Strip out CR and leading/trailing space.
        descriptions[line.split.first] = line.split(/\s{12,14}/).last.chomp.strip
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

  def clock
    ssh("show clock").each_line do |line|
      puts line
    end
  end

  def version
    ssh("show version").each_line do |line|
      puts line.split.last if line =~ /system:/ && line =~ /version/
    end
  end

  def active_zones
    active_zones = []
    ssh("show zoneset active").each_line do |line|
      active_zones << line.split[2] if line =~ /zone name/
    end
    active_zones
  end

  def all_zones
    all_zones = []
    ssh("show zone").each_line do |line|
      all_zones << line.split[2] if line =~ /zone name/
    end
    all_zones
  end

  def no_shows
    @active = active_zones
    @all = all_zones
    @inactive_zones = ( @active | @all ) - @active
    @inactive_zones.each do |zonename|
      puts INDENT + "#{zonename} is not in the active zoneset"
    end
  end

end # of Switch
