require 'sinatra/base'

class OldAPIRedirect < Sinatra::Base

  enable :logging

# Redirect old volumes stuff
#  RewriteRule   ^/api/volumes/(full|brief)/([^/]+)/(.+)[.](json)$ static/api/volumes.php?q=$2:$3&type=$\4&single=1&brevity=$1 [QSA,L]

  get '/:full_brief/:key/*.json' do |brev, key, id|
    status 303
    redirect "http://mirlyn.lib.umich.edu/static/api/volumes.php?q=#{key}:#{id}&type=json&single=1&breviey=#{brev}"
  end


end
