#--
# Copyright 2014 by Martin Horner (martin@mujosan.com)
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
############ Constant Definitions ###########
PATH = "/usr/local/san/cisco/"
INDENT = '    '
HEAD = "#########################################################"
TAIL = "#########################################################"
#############################################
class Switch

  include Common
  
  def initialize(name)
    @name = name
  end

  # This method runs a CLI (show) command against the switch.
  #
  # Exception handling included for:
  #   Net::SSH::Exception - corrupted mac detected
  #
  #   This exception handling makes 10 attempts to get the running config before moving on to the next switch
  #   with a 10sec delay between attempts. This should get around the flakey behaviour of ssh due to the bug
  #   with the OpenSSH implementation on nx-os.
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

  def version
    ssh("show version").each_line do |line|
      puts line.split.last if line =~ /system:/ && line =~ /version/
    end
  end

end # of Switch
