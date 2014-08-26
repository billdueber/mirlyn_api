require 'sinatra/base'
#require 'sinatra/config_file'
require 'sinatra/json'
require 'json'
require 'mirlyn_id_api'

class SimpleMirlynAPI < Sinatra::Base

#  register Sinatra::ConfigFile

#  config_file File.join(File.dirname(__FILE__), 'config.yml')
  enable :logging
  enable :prefixed_redirects

  configure do
    set :client, MirlynIdApi::SolrClient.new("http://solr-vufind:8026/solr/biblio")
  end

  get '/' do
    json({'valid_keys' => {
          'id' => 'Mirlyn Record ID',
          'issn' => "ISSN",
          'oclc' => 'OCLC Number',
          'isbn' => "ISBN",
          'lccn' => "Library of Congress Call Number"
         }})
  end

  get '/:key/:val' do
     resp = settings.client.kv_search(params[:key], params[:val])
     if resp.empty?
       status 404
       json resp.to_h
     else
       json resp.to_h
     end
  end

  run! if app_file == $0
end
