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
# svc_offline_hosts.rb
#
# This script lists the hosts registered on the SVC clusters that are showing 
# all ports either "offline" or "degraded".
#
# There are options to restrict the script to a specific cluster and show 
# hosts that are active but with offline ports.
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
    options.clusters = ['is3501','is3511','is3512']
    options.deadpaths = false

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: svc_offline_hosts.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("--svc CLUSTER", "Enter specific cluster") do |cluster|
        options.clusters = []
        options.clusters << cluster
      end

      opts.on("--dead_paths", "Print out hosts with dead paths") do |deadpaths|
        options.deadpaths = true
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        puts
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
    @host_list = Hostlist.new(cluster)
  end

  def inactive
    @host_list.hosts.each do |host|
      current_host = Host.new(host,@cluster)
      puts "#{current_host.name} - #{current_host.status}" unless current_host.active?
    end
  end

  def find_dead_paths
    @host_list.hosts.each do |host|
      current_host = Host.new(host,@cluster)
      puts "#{current_host.name} - #{current_host.status}" if current_host.dead_path?
    end
  end

end # of Cluster

class Host

  attr_reader :name

  def initialize(host,cluster)
    @name = host
    @cluster = cluster
    @hstatus = {}
    @lshost = %x[svc #{@cluster} i lshost #{@name}]
  end

  def active?
    true if @lshost =~ /active/
  end

  def dead_path?
    true if (@lshost =~ /degraded/ || @lshost =~ /offline/) && @lshost =~ / active/
  end

  def status
    @lshost.each_line do |line|
      case line
      when /^WWPN/
        @wwpn = line.split.last
      when /^state/
        @hstatus[@wwpn] = line.split.last
      end
    end
    @hstatus
  end

end

class Hostlist < Array

  attr_reader :hosts

  def initialize(cluster)
    @clustername = cluster
    @hosts = []
    %x[svc #{@clustername} i lshost -nohdr -delim :].each_line do |line|
      @hosts << line.split(":")[1]
    end
  end

end

#############################################
################ Main Script ################
options = OptionParse.parse(ARGV)

options.clusters.each do |clustername|
  puts "Checking #{clustername.upcase}..."
  c = Cluster.new(clustername)
  c.inactive
  c.find_dead_paths if options.deadpaths
end
