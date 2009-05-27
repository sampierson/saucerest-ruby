require 'rubygems'
require 'net/ssh'
require 'net/ssh/gateway'
require 'saucerest'

username = ""
access_key = ""
domains = ['www.1234.dev']
local_port = 5000
local_host = "localhost"
remote_port = 80

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

response = sauce.create(:tunnel,
                        'DomainNames' => domains)
p response
tunnel_id = response['id']
begin
  interval = 10
  timeout = 600
  t = 0
  while t < timeout
    tunnel = sauce.get :tunnel, tunnel_id
    p tunnel
    if tunnel['Status'] == 'running'
      break
    end

    puts "sleeping..."
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
ensure
  puts "Aborted -- shutting down tunnel"
  sauce.delete :tunnel, tunnel_id
end
