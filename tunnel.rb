#! /usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# Copyright (c) 2009 Sauce Labs Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# 'Software'), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'rubygems'
require 'net/ssh'
require 'net/ssh/gateway'
require 'saucerest'
require 'optparse'

options = {}
op = OptionParser.new do |opts|
  opts.banner = "Usage: tunnel.rb [options] <username> <access key> <local host> <local port> <remote port> <remote domain> [<remote domain>...]"
  opts.separator ""
  opts.separator "Specific options:"

  opts.on("-d", "--daemonize", "background the process once the tunnel is established") do |d|
    options[:daemonize] = d
  end

  opts.on("-p", "--pidfile FILE", "when used with --daemonize, write backgrounded Process ID to FILE [default: %default]") do |p|
    options[:pidfile] = p
  end

  opts.on("-r", "--readyfile FILE", "create FILE when the tunnel is ready") do |r| 
    options[:readyfile] = r
  end

  opts.on("-s", "--shutdown", "shutdown any existing tunnel machines using one or more requested domain names") do |s| 
    options[:shutdown] = s
  end
end

opts = op.parse!

# TODO: Analize the options inserted and do something with them
# p options

num_missing = 6 - opts.length
if num_missing > 0
  puts 'Missing %d required argument(s)' % [num_missing]
  puts
  puts op
  exit
end

username = opts[0]
access_key = opts[1]
local_host = opts[2]
local_port = Integer(opts[3])
remote_port = Integer(opts[4])
domains = opts[5..-1]


# http://groups.google.com/group/capistrano/browse_thread/thread/455c0c8a6faa9cc8?pli=1
class Net::SSH::Gateway
  # Opens a SSH tunnel from a port on a remote host to a given host and port
  # on the local side
  # (equivalent to openssh -R parameter)
  def open_remote(port, host, remote_port, remote_host = "127.0.0.1")
    ensure_open!

    @session_mutex.synchronize do
      @session.forward.remote(port, host, remote_port, remote_host)
    end

    if block_given?
      begin
        yield [remote_port, remote_host]
      ensure
        close_remote(remote_port, remote_host)
      end
    else
      return [remote_port, remote_host]
    end
  rescue Errno::EADDRINUSE
    retry
  end

  # Cancels port-forwarding over an open port that was previously opened via
  # #open_remote.
  def close_remote(port, host = "127.0.0.1")
    ensure_open!

    @session_mutex.synchronize do
      @session.forward.cancel_remote(port, host)
    end
  end
end

sauce = SauceREST::Client.new "https://#{username}:#{access_key}@saucelabs.com/rest/#{username}/"

puts "Launching tunnel machine..."
response = sauce.create(:tunnel,
                        'DomainNames' => domains)

if  response.has_key? 'error' 
  puts "Error: %s" % [response['error']]
  exit
end

tunnel_id = response['id']
puts "Tunnel id: %s" % tunnel_id

begin
  interval = 10
  timeout = 600
  t = 0
  while t < timeout
    tunnel = sauce.get :tunnel, tunnel_id
    puts "Status: %s" % tunnel['Status']
    if tunnel['Status'] == 'running'
      break
    end

    sleep interval
    t += interval
  end

  gateway = Net::SSH::Gateway.new(tunnel['Host'], username,
                                  options={:password => access_key})
  gateway.open_remote(local_port, local_host, remote_port, "0.0.0.0") do |rp, rh|
    puts "ssh remote tunnel opened"
    # instead of sleeping, you could launch your tests here
    sleep 1500
  end
  gateway.shutdown!
rescue Interrupt
  nil

ensure
  puts "Aborted -- shutting down tunnel"
  sauce.delete :tunnel, tunnel_id
end
