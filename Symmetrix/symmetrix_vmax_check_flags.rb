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
# symmetrix_vmax_check_flags.rb
#
# This script interrogates the Symmetrix, via symmcli, and queries status information relating to the
# flags set against initiators that are logged-in to the array.
#
############ Required Libraries #############
require 'rexml/document'
include REXML
#############################################
############ Variable Definitions ###########
# Array to store the Symmetrix names
symmetrix = [ '1234' ]
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
    @sid = sid                                  # Store global for the SID.
  end # of initialize

  def list_ig
    @initiators = []
    @symcli = Document.new %x[symaccess -sid #{@sid} list -type initiator -output xml]
    @symcli.each_element('///group_name') { |ig| @initiators << ig.text }
    @initiators
  end

  def showflags
    list_ig.each do |name|
      @symcli = Document.new %x[symaccess -sid #{@sid} -type initiator -detail show #{name} -output xml]
      flagset = ""
      if @symcli.elements['//port_flag_overrides'].text == "Yes"
        @symcli.elements['///Override_Flags'].each_recursive {|f| flagset << "#{f.name.to_flag} " }
      else
        flagset = "none"
      end
      puts "#{name.upcase.ljust(15)} - #{flagset}"
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
