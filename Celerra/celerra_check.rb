#!/usr/bin/ruby -w
#
# check_celerra.rb
#
# This script interrogates the EMC Celerras, via SSH, and queries status information.
# Any failures or variances from previous script execution is reported.
#
# Change History:
# ===============
# v0.1 - MH - First working release.
# v0.2 - MH - Ignore call home failures.
# v0.3 - MH - Ignore disk or SP failures (these would be covered by check_clariion).

############### Required Gems ###############
require 'rubygems'
require 'net/ssh'
#############################################
############ Variable Definitions ###########
celerras = [ 'en2075','en1874','en2305' ]
#############################################
############ Constant Definitions ###########
INDENT = "\n......"
#############################################
######### Class/Module Definitions ##########
class Celerra

  def initialize(name)
    @name = name
    # SSH to this Celerra and download the required log files
    Net::SSH.start( name, "script", :password => 'password123' ) do |ssh|
      @daily = ssh.exec!("cat log/daily.log")
    end
  end

  def faults
    fault_description = []                      # Array to hold fault descriptions.
    @daily.each("\n") do |line|
      case
      when line =~ /Control Station/ && ( line =~ /Fail/ || line =~ /Warn/ )
        fault_description << INDENT + line.squeeze(" .").chomp
        next
      when line =~ /Data Movers/ && ( line =~ /Fail/ || line =~ /Warn/ )
        fault_description << INDENT + line.squeeze(" .").chomp
        next
      when line =~ /Storage System/ && ( line =~ /Fail/ || line =~ /Warn/ )
        fault_description << INDENT + line.squeeze(" .").chomp
        next
      end
    end
    if fault_description.length > 0
      fault_description.unshift("Following issues found:")
    else
      fault_description << "ok."
    end
    fault_description << "\n"
    fault_description.each {|f| print f }
  end

end # of Celerra
#############################################

################ Main Script ################
celerras.each do |name|
  print "Checking #{name.upcase}..."
  c = Celerra.new(name)
  c.faults                                       # Determine what is wrong.
end
#################### End ####################

