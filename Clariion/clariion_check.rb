#!/usr/local/bin/ruby -w
#
# check_clariion.rb
#
# This script interrogates the Clariions, via naiseccli, and queries status information.
# Any failures or variances from previous script execution is reported.
#
# Change History:
# ===============
# v0.1 - MH - First working release.
# v0.2 - MH - Ignore disk state of "Empty" - its ok.
# v0.3 - MH - Refactored to be more object-oriented.

############### Required Gems ###############
require "optparse"
require "ostruct"
#############################################
############ Variable Definitions ###########
#############################################
############ Constant Definitions ###########
INDENT = "...."
#############################################
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.clariions = ['clariion01','clariion02','vnx01']

    option_parser = OptionParser.new do |opts|
      opts.banner = "Usage: clariion_check.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-i CLARIION", "Enter specific Clariion") do |clariion|
        options.clariions = []
        clariion = clariion + "_spa" unless clariion.end_with?("spa")
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

class Clariion
  attr_reader :name

  def initialize(name)
    @name = name 
    @state = {}
    @type = {}
    @default_owner = {}
    @current_owner = {}
    lunid = []
    naviseccli("getlun -state -type -default -owner -capacity").each_line do |line|
      case line.downcase
      when /^logical unit number/
        lunid.push line.split.last.strip
        next
      when /^state:/
        @state[lunid[-1]] = line.split(":").last.strip
        next
      when /^raid type/
        @type[lunid[-1]] = line.split(":").last.strip
        next
      when /^default owner/
        @default_owner[lunid[-1]] = line.split.last.strip
        next
      when /^current owner/
        @current_owner[lunid[-1]] = line.split.last.strip
        next
      end  
    end
  end # of initialize

  def naviseccli(cmd)
    %x[/opt/Navisphere/bin/naviseccli -h #{@name} #{cmd}].chop
  end

  def faults
    @faults = []                      # Array to hold fault descriptions.
    @faults << cache_faults
    @faults << cru_faults
    @faults << disk_faults
    @faults << lun_faults
    @faults << trespasses
    @faults << raid_group_faults
    @faults
  end

  def cache_faults
    faults = []                      # Array to hold fault descriptions.
    naviseccli("getcache -state -rsta -rstb -wst").each_line do |line|
      faults << line.squeeze.chomp unless line =~ /Cache State/ && line =~ /Enabled/
    end
    faults.compact unless faults.empty?
  end

  def cru_faults
    faults = []                      # Array to hold fault descriptions.
    naviseccli("getcrus").each_line do |line|
      faults << line.chomp if line =~ /DAE/ && line =~ /FAULT/
      faults << line.chomp if line =~ /State/ && !( line =~ /Present/ || line =~ /Valid/ )
    end
    faults unless faults.empty?
  end

  def disk_faults
    faults = []                      # Array to hold fault descriptions.
    @disks = naviseccli("getdisk -state")
    @disks.gsub!(/\nState:\s+ /, ' State: ')
    @disks.gsub!(/\nBus/, 'Bus')
    @disks.each_line do |line|
      if line =~ /State/
        unless line =~ /Enabled/ || line =~ /Hot Spare Ready/ || line =~ /Unbound/ || line =~ /Empty/
          faults << "Bus #{line.split[1]} Enclosure #{line.split[3]} Disk #{line.split[5]} is #{line.split(':').last}"
        end
      end
    end
    faults unless faults.empty?
  end

  def lun_faults
    faults = []                      # Array to hold fault descriptions.
    @state.each do |lun,status|
      faults << "LUN #{lun} is faulted!" if status == /Faulted/
    end
    faults unless faults.empty?
  end

  def trespasses
    trespasses = 0
    faults = []                      # Array to hold fault descriptions.
    @default_owner.each do |lun, owner|
      if @current_owner[lun] != owner && @type[lun] != 'Hot Spare'
        faults << "Trespassed LUNs:" unless trespasses > 0
        faults << "#{lun} (should be on #{owner} now on #{@current_owner[lun]})"
        trespasses += 1
      end
    end
    faults unless faults.empty?
  end

  def raid_group_faults
    @rgs = naviseccli("getrg -state")
    @rgs.gsub!(/^RaidGroup ID:\s+/, 'RaidGroup: ')   # Remove redundant text & white space
    @rgs.gsub!(/\nRaidGroup:/, 'RaidGroup:')         # Remove newline
    @rgs.gsub!(/\nRaidGroup State:\s+/, '~')         # Swap text for a tilde char
    @rgs.gsub!(/\n \s+/, '~')                        # Swap newline & whitespace for a tilde char
    faults = []                                      # Array to hold fault descriptions.
    @rgs.each_line do |line|
      faults << "RG #{line.split[1]} is faulted!" if line =~ /Invalid/ || line =~ /Halted/ || line =~ /Busy/
    end
    faults unless faults.empty?
  end

end #of Clariion
#############################################
################ Main Script ################
options = OptionParse.parse(ARGV)

options.clariions.each do |name|
  print "Checking #{name.split("_").first.upcase}..."
  c = Clariion.new(name)
  faults = c.faults
  unless faults
    puts "ok."
  else
    puts "Following issues found:"
    puts faults.compact
  end
end
#################### End ####################

