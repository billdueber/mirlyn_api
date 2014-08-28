$:.unshift 'lib'

require 'simple_mirlyn_api'
require 'old_api_redirect'


map '/simple/v1' do
  run SimpleMirlynAPI
end

map '/volumes' do
  run OldAPIRedirect
end
