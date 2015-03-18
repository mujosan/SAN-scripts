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
# svc_consolidation.rb
#
# This script lists the hosts on each cluster. For each host it lists the vdisks.
# Where a host has more than 10 vdisks under 50GB details are output to the console.
#

############### Required Gems ###############
require 'optparse'
require 'ostruct'
#############################################
############ Variable Definitions ###########
#############################################
############ Constant Definitions ###########
#############################################
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.clusters = ['cluster1','cluster2','cluster3']
    options.fileofhosts = "consolidated_hosts.csv"
    options.verbose = false
    options.csv = false
    options.maximum = 50.0
    options.quantity = 10

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: svc_lun_consolidation.rb [options]"
      opts.separator "Default criterion: Hosts with more than 10 LUNs that are less than 50GB"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("--svc CLUSTER", "Enter specific cluster") do |cluster|
        options.clusters = []
        options.clusters << cluster
      end

      opts.on("--max-lun-size LUNSIZE", "Maximum LUN size (GB)") do |maxlunsize|
        options.maximum = maxlunsize.to_f
      end

      opts.on("--num-luns NUMoLUNs", "Number of LUNs") do |numluns|
        options.quantity = numluns.to_i
      end

      opts.on("--file FILEofHOSTs", "File Listing Hosts That Have Been Consolidated") do |fileofhosts|
        options.fileofhosts = fileofhosts
      end

      opts.on("-v", "--verbose", "Output LUN details") do
        options.verbose = true
      end

      opts.on("-c", "--csv", "Output as CSV") do
        options.csv = true
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

  def initialize(cluster,verbose,csv,max,num,fileofhosts)
    @cluster = cluster
    @verbose = verbose
    @csv = csv
    @maximum_size = max
    @number_of_luns = num
    @fileofhosts = fileofhosts
    @lshost = %x[svc #{cluster} i lshost -nohdr -delim :]
    @lsvdisk = %x[svc #{cluster} i lsvdisk -nohdr -delim :]
    @hosts = get_hosts
    @sizes = get_vdisk_sizes
    @uids = get_vdisk_uids
  end

  def get_hosts
    if File.exists?(@fileofhosts)
      host_done = File.readlines(@fileofhosts).map(&:chomp)
    else
      host_done = []
    end
    host_list = []
    @lshost.each_line do |line|
      unless host_done.include?(line.split(":")[1].upcase)  # unless host already consolidated...
        host_list << line.split(":")[1]
      end
    end
    host_list.sort
  end

  def get_vdisk_sizes
    vdisk_size = {}
    @lsvdisk.each_line do |line|
      vdisk_size[line.split(":")[1]] = line.split(":")[7].delete("GB")
    end
    vdisk_size
  end

  def get_vdisk_uids
    vdisk_uid = {}
    @lsvdisk.each_line do |line|
      vdisk_uid[line.split(":")[1]] = line.split(":")[13]
    end
    vdisk_uid
  end

  def print_candidates
    @hosts.each do |host|
      small_luns = @sizes.select{|k,v| v.to_f <= @maximum_size}
      host_small_luns = small_luns.select{|k,v| k.include?(host)}
      if host_small_luns.length > @number_of_luns
        if @verbose
          if @csv
            host_small_luns.each_pair do |name, size|
              puts "#{@cluster},#{host},#{name},#{size},#{@uids.values_at(name).to_s.gsub(/[\[\]"]/, '')}"
            end
          else
            puts "#{host} has #{host_small_luns.length} x LUNs under #{@maximum_size.to_i}GB"
            host_small_luns.each_pair do |name, size|
              puts "#{name} - #{size} - #{@uids.values_at(name).to_s.gsub(/[\[\]"]/, '')}"
            end
          end
        else
          if @csv
            puts "#{@cluster},#{host},#{host_small_luns.length}"
          else
            puts "#{host} has #{host_small_luns.length} x LUNs under #{@maximum_size.to_i}GB"
          end
        end
      end
    end
  end

end # of Cluster

#############################################
################ Main Script ################
options = OptionParse.parse(ARGV)

options.clusters.each do |clustername|
  puts "Checking #{clustername.upcase} for hosts with 
        more than #{options.quantity}LUNs 
        under #{options.maximum}GB..." unless options.csv
  c = Cluster.new(clustername,options.verbose,options.csv,options.maximum,options.quantity,options.fileofhosts)
  c.print_candidates
end
