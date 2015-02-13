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

# This file contains the class definition for EMC Clariion/VNX storage arrays.

############### Required Gems ###############
require "optparse"
require "ostruct"
require 'timeout'
require 'time'
#############################################
class String

  def parse_trespass
    self.gsub!(/^L\w+\s\w+\s\w+\s+/, '')              # Remove LOGICAL LUN NUMBER text
    self.gsub!(/\n\w{7}\s\w+:\s+/, ',')               # Replace Default/Current O/owner text with a comma
    self.gsub!(/\nRAID Type:\s+/, ',')                # Replace RAID Type text with a comma
    self.gsub!(/^\n/, '')                             # Remove redundant newlines
  end

  def parse_disk
    self.gsub!(/\nState:\s+ /, ' State: ')
    self.gsub!(/\nBus/, 'Bus')
  end

  def parse_lun
    self.gsub!(/^L\w+\s\w+\s\w+\s+/, '')              # Remove LOGICAL LUN NUMBER text
    self.gsub!(/\nState:\s+/, ' ')
    self.gsub!(/^\n/, '')
  end

  def parse_rg
    self.gsub!(/^RaidGroup ID:\s+/, 'RaidGroup: ')   # Remove redundant text & white space
    self.gsub!(/\nRaidGroup:/, 'RaidGroup:')         # Remove newline
    self.gsub!(/\nRaidGroup State:\s+/, '~')         # Swap text for a tilde char
    self.gsub!(/\n \s+/, '~')                        # Swap newline & whitespace for a tilde char
  end

end

class Clariion
  attr_reader :name

  def initialize(name)
    @name = name
  end # of initialize

  def naviseccli(cmd)
    begin
      try_three_times(cmd, "a")
    rescue Timeout::Error => e
      try_three_times(cmd, "b")
    end
  end

  def try_three_times(cmd,sp)
    tries = 0
    begin
      tries += 1
      Timeout.timeout(300) do                         # Time out if no response from SPA within 5mins.
        %x[/opt/Navisphere/bin/naviseccli -h #{@name}_sp#{sp} #{cmd}].chop
      end
    rescue Timeout::Error => e
      retry if tries < 3
      puts "No response from SP#{sp.upcase}"
      return " "
    end
  end

  def faults
    @faults = []                      # Array to hold fault descriptions.
    @faults << cache_faults
    @faults << cru_faults
    @faults << disk_faults
    @faults << lun_faults
    @faults << trespasses
    @faults << raid_group_faults
    @faults << time_faults
    @faults.flatten!
    @faults.compact
  end

  def cache_faults
    faults = []                      # Array to hold fault descriptions.
    naviseccli("getcache -state -rsta -rstb -wst").each_line do |line|
      faults << "Cache Fault => #{line.squeeze.chomp}" unless line =~ /Cache State/ && line =~ /Enabled/
    end
    faults
  end

  def cru_faults
    faults = []                      # Array to hold fault descriptions.
    naviseccli("getcrus").each_line do |line|
      faults << "CRU Fault   => #{line.chomp}" if line =~ /DAE/ && line =~ /FAULT/
      faults << "CRU Fault   => #{line.chomp}" if line =~ /State/ && !( line =~ /Present/ || line =~ /Valid/ )
    end
    faults
  end

  def disk_faults
    faults = []                      # Array to hold fault descriptions.
    naviseccli("getdisk -state").parse_disk.each_line do |line|
      if line =~ /State/
        unless line =~ /Enabled/ || line =~ /Hot Spare Ready/ || line =~ /Unbound/ || line =~ /Empty/
          faults << "Disk Fault  => Bus #{line.split[1]} Enclosure #{line.split[3]} Disk #{line.split[5]} " +
                    "is #{line.split(':').last.lstrip}"
        end
      end
    end
    faults
  end

  def lun_faults
    faults = []                      # Array to hold fault descriptions.
    naviseccli("getlun -state").parse_lun.each_line do |line|
      faults << "LUN Fault   => ALU #{line.split.first}" if line =~ /Faulted/
    end
    faults
  end

  def trespasses
    faults = []                      # Array to hold fault descriptions.
    naviseccli("getlun -default -owner -type").parse_trespass.each_line do |line|
      if line.split(",")[1] != line.split(",")[2] && line.split(",").last.chomp != 'Hot Spare'
        faults << "Trespass    => ALU #{line.split(",").first} should be on #{line.split(",")[1]} " +
                                  "now on #{line.split(",")[2]}"
      end
    end
    faults
  end

  def raid_group_faults
    faults = []                                      # Array to hold fault descriptions.
    naviseccli("getrg -state").parse_rg.each_line do |line|
      faults << "RAID Group Fault => #{line.split[1]}" if line =~ /Invalid/ || line =~ /Halted/ || line =~ /Busy/
    end
    faults
  end

  def time_faults
    faults = []                                      # Array to hold fault descriptions.
    @sptimes = naviseccli("getsptime")
    @now = Time.now
    @sptimes.each_line do |line|
      timestring = line.split(/[AB]:/).last.lstrip.chomp
      sptime = Time.strptime(timestring, "%m/%d/%y %H:%M:%S")  # Extract SP time
      difference = (@now - sptime)                   # Compare SP time to current time
      if difference > 600                            # If time difference > 5mins
        faults << "#{line.split(/:/).first} is #{( difference / 60 ).abs} minutes out!"
      end
    end
    faults
  end

  def nars2get
    nar_available = []
    nar_stored = []
    naviseccli("analyzer -archive -list").each_line do |line|
      if line =~ /^\d/
        nar_available << line.split.last
      end
    end
    Dir.glob(NARDIR + '*.nar').each do |line|
      nar_stored << line.split("/").last
    end
    # List NAR file names that are available but not stored
    (nar_stored | nar_available) - nar_stored
  end

  def get_nars
    if nars2get.length > 0
      narlist = nars2get.to_s.gsub(/\",*/, '')[1..-2]
      naviseccli("analyzer -archive -path #{NARDIR} -file #{narlist} -o")
    end
  end
end # of class Clariion
