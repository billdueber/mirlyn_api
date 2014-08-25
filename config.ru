#app_bundle_dir = File.join(File.dirname(__FILE__), '.bundle')
#$:.unshift(app_bundle_dir) unless
#  $:.include?(app_bundle_dir) || $:.include?(File.expand_path(app_bundle_dir))
require './simple_mirlyn_api'
run SimpleMirlynAPI

