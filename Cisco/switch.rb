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

# This file contains the class definition for SAN switches.
# For the purposes of the internal workings of this class all
# switches will be assumed to be Cisco MDS.
# Brocade? Never heard of it!
############### Required Files ##############
require_relative '../common'
############### Required Gems ###############
require "net/ssh"
require "net/scp"
#############################################
class Switch

  include Common
  
  def initialize(name)
    @switchname = name
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
      Net::SSH.start( @switchname, "script", :password => 'password' ) do |ssh|
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
  
  def scp(source, destination)
    begin
      Net::SCP.start(@switchname, "script", :password => 'password' ) do |scp|
        scp.download!(source, destination)
      end
    rescue Net::SCP::Error => error
      puts "Net::SCP::Error has occurred: #{error.inspect}"
    end
  end
  
  def backup_licenses(licensefilepath)
    result = ssh("copy licenses bootflash:license_file.tar")
    scp("bootflash:license_file.tar", licensefilepath)
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

  def uptime
    ssh("show system uptime").each_line do |line|
      if line =~ /System uptime/
        @system_uptime = line.gsub(/System uptime:              /, '')
      end
    end
    @system_uptime
  end

end # of Switch
