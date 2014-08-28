require 'sinatra/base'
require 'sinatra/jsonp'
require 'json'
require 'mirlyn_id_api'


class SimpleMirlynAPI < Sinatra::Base

  helpers Sinatra::Jsonp

  enable :logging
  enable :prefixed_redirects
  set :client, MirlynIdApi::SolrClient.new(ENV['MIRLYN_SOLR_URL'])
  set :root, ENV['MIRLYN_API_APPLICATION_ROOT']


  helpers do
    def malformed!(type, val)
      status 400
      jsonp({'status' => status, 'error' => "'#{val}' cannot be interpreted as an #{type}"})
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
    jsonp({'status' => status, 'error' => "Search key '#{params[:key]}' is not supported"})
  end


  run! if app_file == $0
end
