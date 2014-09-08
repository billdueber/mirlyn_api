require 'sinatra/base'
require 'sinatra/jsonp'
require 'json'
require 'mirlyn_id_api'
require 'socket'

class MirlynDocumentPresenter < MirlynIdApi::MirlynSolrDocument
  def initialize(mdoc)
    @doc = mdoc.solr_doc_hash
  end

  # We get title, the identifiers, *holdings, and catalog_url for free
  # from the superclass

  def record_id
    @doc['id']
  end

  def main_author
    [@doc['mainauthor'], @doc['author']].flatten.first
  end

  def other_authors
    [@doc['author'], @doc['author2']].flatten.compact.uniq - [main_author]
  end

  def languages
    Array(@doc['language']).uniq
  end

  def formats
    Array(@doc['format']).uniq
  end

  def publication_date
    @doc['publishDate'].first
  end

  def pages
    candidate = marc['300'] && marc['300']['a']
    m = /(\d+)\s*p/.match(candidate)
    m ? m[1] : candidate
  end

  def e_holdings
    [electronic_holdings, ht_holdings].flatten.compact.uniq
  end


  def to_h
    h = {
        'id' => record_id,
        'catalog_url' => catalog_url,
        'title' => title,
        'languages' => languages,
        'main_author' => main_author,
        'other_authors' => other_authors,
        'formats' => formats,
        'pages' => pages,
        'publication_date' => publication_date,
        'print_holdings' => print_holdings.map(&:to_h),
        'electronic_holdings' => e_holdings.map(&:to_h)
    }

    h['oclc'] = oclc if oclc
    h['isbn'] = isbn if isbn
    h['issn'] = issn if issn
    h['lccn'] = lccn if lccn

    h

  end


end

class SimpleMirlynAPI < Sinatra::Base

  helpers Sinatra::Jsonp

  enable :logging
  enable :prefixed_redirects
  set :client, MirlynIdApi::SolrClient.new(ENV['MIRLYN_SOLR_URL'])
  set :root, ENV['MIRLYN_API_APPLICATION_ROOT']
  set :default_encoding, 'utf-8'


  # Make sure json is sent with the charset (utf-8)
  settings.add_charset << 'application/json'


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
        rv = resp
        rv.docs.map! {|x| MirlynDocumentPresenter.new(x)}
        
        rv = rv.to_h.merge({'status' => 200})

        rv['hostname'] = Socket.gethostname

        jsonp rv
      end
    end
  end


  get '/' do
    jsonp({'valid_keys' => {
          'id' => 'Mirlyn Record ID',
          'issn' => "ISSN",
          'oclc' => 'OCLC Number',
          'isbn' => "ISBN",
          'lccn' => "Library of Congress Call Number",
          'htid' => "HathiTrust ID"
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
    unless StdNum::ISSN.reduce_to_basics(val, 8)
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

  get '/htid/:val' do |htid|
    kv_search('ht_id', htid)
  end

  # Catch all
  get '/:key/:val' do
    status 405
    jsonp({'status' => status, 'error' => "Search key '#{params[:key]}' is not supported"})
  end


  run! if app_file == $0
end
