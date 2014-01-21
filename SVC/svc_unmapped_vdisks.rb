#!/usr/local/bin/ruby

#--
# Copyright 2013 by Martin Horner (martin.horner@telecom.co.nz)
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
# svc_unmapped_vdisks.rb
#
# This script lists the Vdisks that are unmapped.
#
# Change History:
# ===============
# v0.1 - MH - First working release.

############### Required Gems ###############
require 'optparse'
require 'ostruct'
#############################################
############ Variable Definitions ###########
#############################################
############ Constant Definitions ###########
INDENT = '    '
#############################################
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.clusters = ['is3501','is3511','is3512']

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: svc_unmapped_vdisks.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("--svc CLUSTER", "Enter specific cluster") do |cluster|
        options.clusters = []
        options.clusters << cluster
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end

    end

    opts.parse!(args)
    options
  end # of parse()

end # of OptionParse

class Cluster

  def initialize(cluster)
    @cluster = cluster
    @all_vdisks = get_all_vdisks
    @mapped_vdisks = get_mapped_vdisks
  end

  def get_all_vdisks
    all = []
    %x[svc #{@cluster} i lsvdisk -nohdr -delim :].each_line do |line|
      all << line.split(":")[1]
    end
    all
  end

  def get_mapped_vdisks
    mapped = []
    %x[svc #{@cluster} i lshostvdiskmap -nohdr -delim :].each_line do |line|
      mapped << line.split(":")[4]
    end
    mapped
  end

  def unmapped_vdisks
    unmapped = ( @mapped_vdisks | @all_vdisks ) - @mapped_vdisks
    if unmapped.empty?
      puts "ok."
    else
      print "\n"
      unmapped.each do |unmapped|
        puts INDENT + "#{unmapped}"
      end
    end
  end

end # of Cluster

#############################################
################ Main Script ################
options = OptionParse.parse(ARGV)

options.clusters.each do |clustername|
  print "Checking #{clustername.upcase}..."
  c = Cluster.new(clustername)
  c.unmapped_vdisks
end
