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
# getfa.rb
#
# For each FA this script determines the host fanout, number of LUNs and total capacity mapped.
#
# Arguments passed into script:
#        SID (form "123" or "4567")
#        FA (form "8BB" or "14BA")
# Where no FA is specified ALL is assumed (or will be from version 0.4!!).
#
# Change History:
# ===============
# v0.1 - MH - First working release.
# v0.2 - MH - Amended input param reqs to be easier (ie. director/port as "4AB" rather than "4A 0")
# v0.3 - MH - Improvements to performance (running symdev list once instead of symdev show for every device)
# v0.4 - MH - Modifying script to examine whole array if FA not specified
# v0.5 - MH - Send error output from symmaskdb to /dev/null and tidied up some assignment statements
# v0.6 - MH - Replace symmaskdb with symcfg command to find devices mapped (masked or not) to an FA.
# v0.7 - MH - Removed hard-coded check for SID.
#             Disabled STDERR messages to the console during script execution.

# Disable STDERR messages to the console during script execution.
stderr = $stderr                                # Save current STDERR IO instance
$stderr.reopen('/dev/null','w')                 # Send STDERR to /dev/null

# Create a class to store the values relating to the FA that we are interested in.
class Adapter
  attr_reader :sid, :dandp
  attr_accessor :fanout, :luns, :capacity


  def initialize(sid, dandp, fanout, luns, capacity)
    @sid	= sid
    @dandp	= dandp
    @fanout	= fanout
    @luns	= luns
    @capacity	= capacity
    @devlist	= []
  end
  
  # Define a method to extract the director id from the e.g. 4AB
  def get_director(dandp)
    dandp.chop                     # Chop removes the last char (i.e. the port)
  end

  # Define a method to convert an alpha port id (a or b) to a numeric (0 or 1)
  def port_to_i(dandp)
    a = dandp.delete("0-9").upcase        # Remove the numeric portion of the director/port id leaving two alpha chars
    port = a[1,1].tr('A-B','0-1')         # Translate the last alpha into either 0 or 1
  end


  def fanout # Determine how many HBAs are logged into the FA - Fan Out Ratio
    fanout = 0
    # Run a "symmask list logins" command
    symmcli = %x[symmask -sid #{@sid} -dir #{get_director(@dandp)} -p #{port_to_i(@dandp)} list logins]
    symmcli.each("\n") {|line| fanout += 1 if line =~ /Yes\s+Yes/ }  # Count number of HBAs logged in to FA
    fanout
  end

  def luns # Determine how many devices are mapped through the FA
    @devlist.clear if @devlist.length > 0
    range_array = []
    # Run a "symcfg ... -addr list -avail..." command
    symmcli = %x[symcfg -sid #{@sid} -dir #{get_director(@dandp)} -p #{port_to_i(@dandp)} -addr list -avail]
    symmcli.each("\n") do |line|
      # Convert device id to integer and append to array if the line contains "Not Visible"
      @devlist << line.match(/([0-9]|[A-F]){4}\s\sNot/).to_s.to_i(16) if line =~ /Not Visible/
    end
    @devlist.sort!                       # Sort entries into numerical order
    @devlist.uniq!                       # Remove duplicate entries
    @devlist.collect! {|d| "%04X" % d }  # Convert device ids from integer back to hex pad with zeros
    @devlist.length                      # Length of array = number of devices (this value will be returned by method)
  end

  def capacity # Determine how much storage is presented down the FA
    if @devlist.length == 0        # If the device list is empty then storage = 0
      0
    else
      chash = {}                             # Create new hash
      # Run a "symdev list..." command using the first & last elements from devlist array as the RANGE.
      symmcli = %x[symdev list -sid #{@sid} -RANGE #{@devlist.first}:#{@devlist.last}]
      # Parse the output to populate a hash of devid=>MBs pairs.
      symmcli.each("\n") do |line|
        if line =~ /^[0-9A-F]|^[0-9a-f]/
          carray = line.split                        # Split input line (delimited by spaces) into an array,
          chash[carray.first] = carray.last.to_i     # use element 0 for the key & element 9 for the value
        end
      end
      total_mb = 0                                  # Initialise total
      chash.each {|d,c| total_mb += c if @devlist.include?(d) } # Step through hash totalling up the values
      total_mb / 1024                  # Save FA capacity as Gbs (assuming 1GB = 1024MB)
    end
  end

end # of Adapter

# Perform some vaildation on the command line arguments
#fail "Please specify SID as first argument" unless ARGV[0] =~ /364|370|080|3080|285|2285/
if ARGV.length == 1 # Only the SID has been specified so examine every FA in the Symm
  puts "Symmetrix #{ARGV[0]}\nFA\tFanout\tLUNs\tGBs"        # Output headings
  # List active FAs in specified frame - store in an array
  active = []                                           # Create an array to hold a list of active FAs
  # Run a "symcfg list -DIR ALL" command and grep output to get a list of FAs
  symmcli = %x[symcfg -sid #{ARGV[0]} list -DIR ALL | grep FibreChannel]
  symmcli.each("\n") do |line|
    active << line.split[1] + "A" << line.split[1] + "B" # Load array with active FA ports (A & B)
  end
  active.sort!                             # Sort array content in place
  # For each active FA determine the number of mapped devices
  active.each do |d|
    f = Adapter.new(ARGV[0],d,0,0,0)       # Create an Adapter instance to store the values
    # Run a symcfg command to list devices mapped to FA, grep for a totals line, split the line and convert 2nd element to integer
    symmcli = %x[symcfg -sid #{f.sid} list -FA #{f.get_director(d)} -P #{f.port_to_i(d)} -address | grep Mapped].split(':')[1].to_i
    if symmcli > 1                         # if there is more than 1 device (the VCMDB) the FA is in use so...
      puts "#{d}\t1:#{f.fanout}\t#{f.luns}\t#{f.capacity}"  # output the metrics for this FA, tab delimited
    end
  end
  # If > 1 then FA is in use
elsif ARGV.length == 2 # SID and FA specified just examine this FA
  # Create new Adapter object and store command line arguments in it. Initialise other values to 0.
  f = Adapter.new(ARGV[0],ARGV[1],0,0,0)
  puts "The fanout ratio is 1:#{f.fanout}"      # Output the fanout ratio
  puts "The number of LUNs is #{f.luns}"        # Output the number of LUNs
  puts "The total storage is #{f.capacity}GB."  # Output the total storage
else
  fail "Try getfa.rb <sid> [<director&port>]"
end

exit
