require 'sinatra/base'
require 'sinatra/config_file'
require 'sinatra/jsonp'
require 'json'
require 'mirlyn_id_api'

class SimpleMirlynAPI < Sinatra::Base

  register Sinatra::ConfigFile
  helpers Sinatra::Jsonp

  config_file File.join(File.dirname(__FILE__), 'config.yml')
  enable :logging
  enable :prefixed_redirects

  configure do
    set :client, MirlynIdApi::SolrClient.new("http://solr-vufind:8026/solr/biblio")
    set :client, MirlynIdApi::SolrClient.new(settings.solrurl)
  end


  helpers do
    def malformed!(type, val)
      status 400
      jsonp({'status' => status, 'error' => "#{val} cannot be interpreted as an #{type}"})
    end

    def kv_search(key, val)
      resp = settings.client.kv_search(key, val)
      if resp.empty?
        status 404
        rv = resp.to_h
        rv['status'] = 404
        jsonp rv
      else
        jsonp resp.to_h.merge({'status' => 200})
      end
    end


  end


  get '/' do
    jsonp({'valid_keys' => {
          'id' => 'Mirlyn Record ID',
          'issn' => "ISSN",
          'oclc' => 'OCLC Number',
          'isbn' => "ISBN",
          'lccn' => "Library of Congress Call Number"
         }})
  end


  get '/isbn/:val' do
    val = params[:val]
    unless StdNum::ISBN.at_least_trying?(val)
      malformed!('isbn',val)
    else
      kv_search('isbn', val)
    end
  end

  get '/issn/:val' do
    val = params[:val]
    unless StdNum::ISSN.at_least_trying?(val)
      malformed!('issn',val)
    else
      kv_search('issn', val)
    end
  end

  get '/lccn/:val' do
    val = params[:val]
    normalized = StdNum::LCCN.normalize(val)
    unless normalized
      malformed!('lccn', val)
    else
      kv_search('lccn', normalized)
    end
  end

  get '/id/:val' do
    val = params[:val]
    n = val.gsub(/\D/, '')
    kv_search('id',n)
  end

  get '/oclc/:val' do
    val = params[:val]
    n = val.gsub(/\D/, '')
    kv_search('oclc',n)
  end

  # Catch all
  get '/:key/:val' do
    status 405
    jsonp({'status' => status, 'error' => "Search key #{params[:key]} is not supported"})
  end


  run! if app_file == $0
end
