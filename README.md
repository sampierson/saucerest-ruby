SauceREST for Ruby
==================

This is a Ruby library and some command line tools for interacting
with the SauceREST API.

Here are some useful command line tools:


tunnel.rb
---------

This script is used to set up tunnel machines and open the tunnel from
your side. Run it with "-h" to get the parameters required. Example
run:

    $ ruby tunnel.rb username api-key localhost 5000:80 exampleurl.com

This will make our computers masquerade exampleurl.com on port 80
through the tunnel you're about to open.


list_tunnels.rb
---------------

Lists all the available tunnels for the user account given. Example
run:

    $ ruby list_tunnels.rb username api-key


saucerest.rb
------------

This is a basic library for working with the SauceREST API.  If you
plan to write scripts that work with SauceREST in Ruby, `saucerest.rb`
might be a good place to start.
