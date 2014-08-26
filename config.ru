require './simple_mirlyn_api'

map '/simple/v1' do
  run SimpleMirlynAPI
end

