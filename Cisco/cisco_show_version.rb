#!/usr/bin/env ruby
#

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
# cisco_show_version.rb
#
# This script accesses the Cisco switches via SSH and runs a "show version" command.
# The resulting output is parsed and the system version is printed to the console.
#
# Change History:
# ===============
# v0.1 - MH - First working release.

################# Required ##################
require_relative "switch"
#############################################
############ Variable Definitions ###########
# Create an array to store the switch names - access is via SSH and IPs are derived from the /etc/hosts file.
switches = ['switch01','switch02',
            'switch03','switch04',
            'switch05','switch06']
#############################################
################ Main Script ################
switches.each do |switchname|
  print "Checking #{switchname.upcase}..."
  c = Switch.new(switchname)
  c.version
end
#################### End ####################
