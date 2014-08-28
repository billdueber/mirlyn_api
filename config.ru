require './simple_mirlyn_api'


map '/simple/v1' do
  run SimpleMirlynAPI
end

map '/volumes' do
  run OldAPIRedirect
end
