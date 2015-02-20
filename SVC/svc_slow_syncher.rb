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
#
# svc_slow_syncher.rb
#
# This script was created in an environment where there was a concern around
# the performance impact of having multiple relationships within Remote Copy
# consistency groups running in parallel.
#
# A decision was made to limit the number of simultaneous RC relationships
# synching to 6.
#
# This script examines the list of available Remote Copy consistency groups and 
# if none are actively synching it starts the next one.
#
######### Class/Module Definitions ##########
class OptionParse

  def self.parse(args)
    options = OpenStruct.new
    options.cluster = ['cluster1', 'cluster2', cluster3']

    option_parser = OptionParser.new do |opts|
      opts.banner = "Usage: svc_slow_syncher.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on('-c', '--cluster CLUSTERNAME', "Mandatory cluster name") do |cluster|
        if options.cluster.include?(switch.downcase)
          options.cluster = []
          options.cluster << cluster
        else
          puts "Sorry, that cluster is not on the list!"
          puts "Either you have fat fingers or the script needs an update."
          exit
        end
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end

    end

    option_parser.parse!(args)
    options
    
    raise OptionParser::MissingArgument if options.cluster.nil?
  end # of parse()

end # of OptionParse

class MetroMirror

  def initialize(cluster)
    @cluster = cluster
  end

  def list
    @consistgrp = %x[svc #{@cluster} i lsrcconsistgrp | grep metro]
  end

  def running?
    @consistgrp =~ /copying/
  end

  def finished?
    true unless @consistgrp =~ /inconsistent/ || @consistgrp =~ /idling/ || @consistgrp =~ /stopped/
  end

  def get_last_completed
    eventlog = %x[svc #{@cluster} i lseventlog | grep rc_consist_grp | tail -1]
    eventime = "20" + eventlog.split[1][0..1] + "-" + eventlog.split[1][2..3] + "-" + eventlog.split[1][4..5] +
               " " + eventlog.split[1][6..7] + ":" + eventlog.split[1][8..9] + ":" + eventlog.split[1][10..11]
    puts "Completed RC consistency group #{eventlog.split[4]} at #{eventime}"
  end

  def start
    started = false
    @consistgrp.each_line do |line|
      unless line =~ /synchronized/
        if line =~ /inconsistent_stopped/
          %x[svc #{@cluster} t startrcconsistgrp -primary master #{line.split[1]}]
          started = true
          puts "Starting RC consistency group #{line.split[1]} at #{Time.now}"
        elsif line =~ /idling/
          %x[svc #{@cluster} t startrcconsistgrp -force -primary master #{line.split[1]}]
          started = true
          puts "Starting RC consistency group #{line.split[1]} at #{Time.now}"
        end
      end
      return if started
    end
  end

end # of MetroMirror
#############################################

################ Main Script ################
# Get the cluster id
fail "Please specify cluster name" unless ARGV.length > 0
fail "Please specify correct cluster name - cluster1, cluster2 or cluster3" unless ARGV[0] =~ /cluster1|cluster2|cluster3/

mm = MetroMirror.new(ARGV[0])
first = true
loop do                                 # Loop forever
  mm.list                               # List the remote copy consistency groups
  if mm.running?                        # If a chunk is still copying
    sleep 300                           # Sleep for 5mins
    next                                # Jump to next loop
  elsif mm.finished?                    # If all chunks have been copied
    mm.get_last_completed               # Parser finish time of last chunk from event log
    puts "All chunks synchronised!"
    break                               # Break out of the loop
  else
    mm.get_last_completed unless first  # Parser finish time of last chunk from event log
    mm.start                            # Start the next inconsistent remote copy consistency group
    first = false
  end

end
