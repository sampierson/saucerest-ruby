require 'rubygems'
require 'saucerest'

username = ""
access_key = ""

sauce = SauceREST::Client.new "https://#{username}:#{access_key}@saucelabs.com/rest/#{username}/"

p sauce.list(:tunnel)
