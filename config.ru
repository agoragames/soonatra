require 'rubygems'
require 'bundler'
require 'split/dashboard'

Bundler.require

require File.join(File.dirname(__FILE__), 'coming_soon.rb')

require 'yaml'
admin_username = YAML.load_file('config/config.yml')['admin_username']
admin_password = YAML.load_file('config/config.yml')['admin_password']

Split::Dashboard.use Rack::Auth::Basic do |username, password|
  username == admin_username && password == admin_password
end

run Rack::URLMap.new \
  "/"       => ComingSoon.new,
  "/split" => Split::Dashboard.new
