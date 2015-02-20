#!/usr/bin/ruby -w
#
# TheWWNwithNoName.rb
#
# This script derives a list of WWNs without friendly names from all DMXs.
# It then crafts a script of symmask rename commands using WWN/hostname info from the switches.
#
# Change History:
# ===============
# v0.1 - MH - First working release.

require 'rubygems'
require 'net/ssh'
require 'yaml'

switches = ['switch01','switch02','switch03','switch04']

frames = ['123']                                                          # VMAX SID

puts "Switches"
puts "========"

@aliaspwwn = {}                                                           # Hash to hold alias to WWN mappings.
@fcalias = []
switches.each do |name|
  @aliaspwwn.clear if @aliaspwwn.length > 0
  print "#{name.upcase}..."
  Net::SSH.start( name, "script", :password => 'password' ) do |ssh|
    result = ssh.exec!("show running-config")
    @fcalias = result.delete(":").scan(/fcalias name (\w+) (\w+) (\w+)\n\s+(\w+) (\w+) (\w+)/)
    @fcalias.each do |host|
      @aliaspwwn[host[0]] = host[5] if host[0] =~ /\w+_[A|B]/
    end
  end
  puts "...done."
end

outfile = File.new("vmax_symmask_rename.sh", "w")

puts "Symmetrix"
puts "========="

frames.each do |sid|
  print "#{sid}....."
  symaccess = %x[symaccess -sid #{sid} list logins]
  symaccess.each("\n") do |line|
    case line
    when /Fibre/
    # If the identifier is equal to the node name (i.e. friendly name not set) AND the HBA is logged in to the FA
      if (line.split[0] == line.split[2]) && (line.split[5] == 'Yes')
        if @aliaspwwn.has_value?(line.split[0])      # If the hash of host WWNs from the switches has a match
          friendlyname = @aliaspwwn.index(line.split[0]).gsub(/_/, '/')
          outfile.puts "symmask -sid #{sid} -wwn #{line.split[0]} rename #{friendlyname}"
        end
      end
      next
    end
  end

  puts ".....done."
end

puts "Finished!!!"

outfile.close

exit
