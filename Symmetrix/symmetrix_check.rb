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
# symmetrix_check.rb
#
# This script interrogates the Symmetrix, via symmcli, and queries status information.
#
############### Required Gems ###############
require 'rubygems'
#############################################
############ Variable Definitions ###########
# Array to store the Symmetrix names
symmetrix = [ '123' ]
#############################################
############ Constant Definitions ###########
# Hash to store the FA pairs for VMAX
PAIRS123 = {"5EA" => "6EA", "7EA" => "8EA", "9EA" => "10EA", "5FA" => "6FA",
            "5GA" => "6GA", "7GA" => "8GA", "9GA" => "10GA", "7FA" => "8FA",
            "9FA" => "10FA", "5HA" => "6HA", "7HA" => "8HA", "9HA" => "10HA"}

INDENT = "\n......"
#############################################
############ Class Definitions ##############
class Symmetrix

  def initialize(sid)
    @sid = sid
    # List all front directors extracting port and connection status
    @list_fa = %x[symcfg -sid #{sid} list -FA ALL -v | grep Director | grep -v Type | grep -v 'Port:' | egrep -v 'c Num|t Num']
    @list_dir = %x[symcfg -sid #{sid} -dir all list | grep FibreChannel] # List all fibre channel directors
    @list_addr = %x[symcfg -sid #{sid} -dir all list -addr]              # List all LUN addresses for all FAs
    @list_logins = %x[symmask -sid #{sid} -dir all -p all list logins]   # List all logins for all FAs
    @list_fail = %x[symdisk -sid #{sid} list -fail]                      # List any failed disks
    @active = PAIRS123
  end # of initialize

  # Derive a hash of the number of mapped devices per FA
  def mapped
    fa = []                                     # Create stack (array) to hold current FA
    @mappedcount = {}                           # Create hash to hold list of FAs and their mapped device counts
    @list_addr.each_line do |line|              # Iterate through each line in the output of the symcfg -dir all list -addr command
      case line
      when /^    FA/                            # Line starts with "    FA"
        fa.push line.split[1].gsub(/^0/, '') + line.split[2].tr('01','AB')   # Store FA in stack (with port as A or B)
        next                                    # Skip to next line
      when /Available Addresses/                # Line contains "Available Addresses"
        fa.pop                                  # Remove previous FA entry from stack
        next                                    # Skip to next line
      when /Mapped Devices/                     # Line contains "Mapped Devices"
        @mappedcount[fa[-1]] = line.split.last  # Store FA & count key/value pair in the hash
        next
      end
    end
    @mappedcount
  end # of mapped

  # Derive a hash of the number of logins per FA
  def logins
    fa = []                                     # Initialise stack (array) to hold current FA
    @logincount = {}                            # Create hash to hold list of FAs and their login counts
    @list_logins.each_line do |line|            # Iterate through each line in the output of the symmask -dir all list logins command
      case
      when line =~ /Director Id/                # Line contains "Director Id"
        fa.pop                                  # Remove previous FA entry from stack
        fa.push line.split("-").last.chomp      # Store FA (director) in stack
        next                                    # Skip to next line
      when line =~ /Director Port/              # Line contains "Director Port"
        fa[-1] << line.split.last.tr('01','AB') # Append FA port (as A or B) to FA director entry in stack
        @logincount[fa[-1]] = 0                 # Now we have the Director & Port ids initialise a new entry in the logincount hash
        next                                    # Skip to next line
      when line =~ /Yes    Yes/                 # Line contains "Yes    Yes"
        @logincount[fa[-1]] += 1                # Increment logincount
        next
      end
    end
    @logincount
  end # of logins

  # Method to extract the director id from the e.g. 4AB
  def get_director(dandp)
    dandp.to_s.chop                            # Chop removes the last char (i.e. the port)
  end
  
  # Method to convert an alpha port id (a or b) to a numeric (0 or 1)
  def port_to_i(dandp)
    a = dandp.delete("0-9").to_s.upcase        # Remove the numeric portion of the director/port id leaving two alpha chars
    port = a[1,1].to_s.tr('A-B','0-1')         # Translate the last alpha into either 0 or 1
  end

  def faults
    @faults = []
    @faults << fa_faults
    @faults << disk_faults
    @faults.flatten!
    @faults.compact
  end
  
  def fa_faults
    fa = []
    faults = []                                      # Array to hold fault descriptions.
    @list_fa.each_line do |line|
      case line
      when /Identification/                              # when line contains "Identification"...
        fa.push line.split("-")[1].chomp                 # Store FA (director) in stack
        next
      when /Number of Director Ports/                    # when line contains "Number of Director Ports"...
        @numports = line.split(":")[1].chomp.to_i         # Store the number of ports
        next
      when /Director Status/                             # when line contains "Director Status"...
        unless line =~ /Online/                          # unless status is "Online"...
          faults << "FA Fault => " + fa.to_s + " is " + line.split(":")[1]
        end
        next
      when /Director Ports Status/
        unless line.scan(/ON/).length == @numports
          faults << "FA Fault => " + fa.to_s + " has " + line.scan(/ON/).length.to_s +
                             " out of " + @numports.to_s + " ports active."
        end
        next
      when /Director Connection Status/
        unless line.scan(/Yes/).length == @numports
          faults << "FA Fault => " + fa.to_s + " has " + line.scan(/Yes/).length.to_s +
                             " out of " + @numports.to_s + " connections active."
        end
        fa.pop
        next
      end
    end

    @active.each do |a,b|                           # Iterate through each active FA pair
      # Check for any devices assigned to the first member of the FA pair - skip this pair if there aren't any - it's not in use!!
      if @mappedcount[a].to_i > 1
        # Check for more than 1 mapped devices on the first member of the FA pair - skip symmask command if less than 2 mapped devices
        patha = @logincount[a]
        pathb = @logincount[b]
        if patha != pathb && ( patha == 0 || pathb == 0 ) # If the number of logins differ AND either one of the FAs have no logins
          faults << "FA Fault => " + a.to_s + " has " + patha.to_s + " logins whilst " + b.to_s + " has " + pathb.to_s
        end
      end
    end

    faults

  end # of fa_faults

  def disk_faults
    disks = []
    vendor = ""
    product = ""
    serial = ""
    @list_fail.each("\n") do |line|
      disks << line.split[1] + ":" + line.split[2..3].to_s if line =~ /^DF/
    end
    disks.each do |diskid|
      disk_details = %x[symdisk -sid #{@sid} show #{diskid}]
      disk_details.each("\n") do |line|
        case line
        when /Vendor ID/
          vendor = line.split.last
          next
        when /Product ID/
          product = line.split(":").last.chomp
          next
        when /Serial ID/
          serial = line.split.last
          next
        end
      end
      faults << "Disk Fault => " + diskid + " (" + vendor + " " + product + "; Serial ID = " + serial + ") has failed."
    end
      
    faults
  end # of disk_faults

end
#############################################

################ Main Script ################
# Disable STDERR messages to the console during script execution
stderr = $stderr                                # Save current STDERR IO instance
$stderr.reopen('/dev/null','w')                 # Send STDERR to /dev/null

symmetrix.each do |sid|                          # Iterate through each element in array symmetrix
  print "Checking #{sid}..."
  s = Symmetrix.new(sid)                         # Create an instance of class Symmetrix
  faults = s.faults
  if faults.empty?
    puts "ok."
  else
    puts "Following issues found:"
    puts faults
  end
end
#############################################
