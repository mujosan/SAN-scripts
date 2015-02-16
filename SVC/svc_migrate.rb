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
# svc_migrate.rb
#
# This script lists active migrations across all (or specific) SVC clusters
# 
# !! Note - This script is unfinished !!

############ Required libraries #############
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
    options.file = false
    options.host = false

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: svc_migrate.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("--svc CLUSTER", "Enter specific cluster") do |cluster|
        options.clusters = []
        options.clusters << cluster
      end

      opts.on("-f FILE", "--file FILE", String, "Read in a file of LUNs to migrate with destination pool") do |file|
        options.file = file
      end

      opts.on("--host HOST", String, "Enter specific host's LUNs to be migrated") do |host|
        options.host = host
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

class Migration

  def initialize(cluster)
    @cluster = cluster
    @lsmigrate = %x[svc #{cluster} i lsmigrate]
    @lsvdisk = %x[svc #{cluster} i lsvdisk -nohdr -delim :]
    @lsmdiskgrp = %x[svc #{cluster} i lsmdiskgrp -nohdr -delim :]
    @vdisks = get_vdisks
    @mdgs = get_mdisk_groups
    @migrations = get_migrations
  end

  def running?
    @lsmigrate.scan(/migrate_type/).length
  end

  def get_vdisks                    # Populate hash of Vdisks
    vd = {}
    @lsvdisk.each_line do |line|
      vd[line.split(":").first] = line.split(":")[1]
    end
    vd
  end

  def get_mdisk_groups              # Populate hash of mdiskgrps
    md = {}
    @lsmdiskgrp.each_line do |line|
      md[line.split(":").first] = line.split(":")[1]
    end
    md
  end

  def get_migrations                # Populate array of migrations
    progress = ""
    vdisk = ""
    mdg = ""
    mig = []
    @lsmigrate.each_line do |line|
      case line
      when /progress/
        progress = line.split.last
        next
      when /migrate_source_vdisk_index/
        vdisk = @vdisks[line.split.last]
        next
      when /migrate_target_mdisk_grp/
        mdg = @mdgs[line.split.last]
        next
      when /migrate_source_vdisk_copy_id/
        mig << "#{vdisk.ljust(13)} -> #{mdg.ljust(15,'.')}#{progress}%"
        next
      end
    end
    mig.sort
  end # of get_migrations

  def print_migrations
    puts @migrations
  end

  def host_present?(host)
    true if @lsvdisk =~ /"#{host}"/ 
  end

  def migrate_luns(host)
    print "Checking migration workload..."
    if get_migrations.length < 6      # If less than 6 migrations are currently running...
            #find LUNs that are not migrated or migrating
    else
      puts "too many inflight...sleeping."
      sleep 300
    end
  end

end # of Migration

#############################################
################ Main Script ################
options = OptionParse.parse(ARGV)

if options.file
  puts "Migrating LUNs listed in a file."
elsif options.host
  puts "Migrating all LUNs for host #{options.host}."
  options.clusters.each do |clustername|      # Iterate through all clusters
    c = Migration.new(clustername)    #List current migrations
    if c.host_present?(options.host)
      c.migrate_luns(options.host)
    end
  end   
else
  options.clusters.each do |clustername|      # Iterate through all clusters
    puts "Checking #{clustername.upcase}..."
    c = Migration.new(clustername)    #List current migrations
    if c.running?                     #If there are any
      c.print_migrations              #List current migrations
    else
      puts "None!"
    end
  end
end
