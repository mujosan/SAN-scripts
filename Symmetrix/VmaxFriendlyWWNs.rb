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

switches = ['cisdox01','cisdox02','cisdox07','cisdox08','cisdox09','cisdox10','ciswas01','ciswas02','ciswas07','ciswas08','ciswas09','ciswas10','ciswyn07','ciswyn08','ciswyn09','ciswyn10','ciswyn11','ciswyn12']

frames = ['620']

puts "Switches"
puts "========"

@aliaspwwn = {}                                                           # Hash to hold alias to WWN mappings.
@fcalias = []
switches.each do |name|
  @aliaspwwn.clear if @aliaspwwn.length > 0
  print "#{name.upcase}..."
  Net::SSH.start( name, "script", :password => 'Oz3gee6b' ) do |ssh|
    result = ssh.exec!("show running-config")
    @fcalias = result.delete(":").scan(/fcalias name (\w+) (\w+) (\w+)\n\s+(\w+) (\w+) (\w+)/)
#    @fcalias = result.delete(":").scan(/fcalias name (\w+-\w+) (\w+) (\w+)\n\s+(\w+) (\w+) (\w+)/) # Telecom specific HBA naming
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
    when /Fibre/                                       # when line contains "Fibre"
    # If the identifier is equal the node name (i.e. friendly name not set) AND the HBA is logged in to the FA
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
