$:.unshift 'lib'

require 'simple_mirlyn_api'
require 'old_api_redirect'
require 'pod'


map '/simple/v1' do
  run SimpleMirlynAPI
end

map '/pod/v1' do
  run PodAPI
end

map '/volumes' do
  run OldAPIRedirect
end
