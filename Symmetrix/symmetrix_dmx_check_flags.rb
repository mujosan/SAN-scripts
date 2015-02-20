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
# check_symm_flags.rb
#
# This script interrogates the Symmetrix, via symmcli, and queries status information relating to the
# flags set against HBAs that are logged-in to the array.
#
############ Required Libraries #############
require 'rexml/document'
include REXML
#############################################

############ Variable Definitions ###########
# Array to store the Symmetrix names
symmetrix = [ '266' ]
#############################################
############ Constant Definitions ###########
#############################################
############# Class Definitions #############
class String                                    # Add method to existing class
  def to_flag
    case self
    when /scsi_3/
      "sc3"
    when /spc2_protocol_version/
      "spc2"
    when /scsi_support1/
      "os2007"
    else
      self
    end
  end
end

class Symmetrix

  def initialize(sid)
    @sid = sid                                                                                             # Store global for the SID.
  end # of initialize

  def showflags
    @list_logins = Document.new %x[symmask -sid #{sid} list logins -dir all -output xml]                   # List all hba logins
    @logins = {}                                                                                           # Hash for node names & WWNs
    @flags = {}                                                                                            # Hash for WWNs & flag settings
    @list_logins.each_element('//Login') do |login|                                                        # Iterate through symmask output
      if login.elements['logged_in'].text == 'Yes' && login.elements['on_fabric'].text == 'Yes'            # If host logged-in & on fabric...
        @logins[login.elements['awwn_node_name'].text] = login.elements['originator_port_wwn'].text        # store name & wwn in hash
      end
    end
    @list_database = Document.new %x[symmaskdb -sid #{sid} list database -dir ALL -p ALL -v -output xml]   # List all database info (incl hba flags)
    @list_database.each_element('//Db_Record') do |rec|                                                    # Iterate through masking database
      flagset = ""
      if rec.elements['Override_Flags'].has_elements?
        rec.elements['Override_Flags'].each_recursive {|f| flagset << "#{f.name.to_flag} " }
      else
        flagset = "None"
      end
      @flags[rec.elements['originator_port_wwn'].text] = flagset
    end
    @logins.each_pair do |name, wwn|
      if @flags.has_key?(wwn)
        puts "#{name.upcase} - #{@flags.values_at(wwn).to_s}."
      end
    end
  end # of showflags
end
#############################################
################ Main Script ################
# Disable STDERR messages to the console during script execution
stderr = $stderr                                # Save current STDERR IO instance
$stderr.reopen('/dev/null','w')                 # Send STDERR to /dev/null

symmetrix.each do |sid|                          # Iterate through each element in array symmetrix
  puts "Checking #{sid}..."
  s = Symmetrix.new(sid)                         # Create an instance of class Symmetrix
  s.showflags
end
#############################################
