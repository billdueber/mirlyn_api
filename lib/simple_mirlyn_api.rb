require 'sinatra/base'
require 'sinatra/jsonp'
require 'json'
require 'mirlyn_id_api'
require 'socket'
require 'yaml'

# Ok, so I stupidly hooked the locColl.yaml into the MirlynIdApi gem,
# because, you know, I'm stupid.

# I should (and will) fix it For Reals, but in the meantime I'm going to
# pull this out and just override the damn thing

class MirlynIdApi::MirlynHolding

  def location
    return '' # fix it later :-)
    colls = YAML.load_file('/www/vufind/web/mirlyn/web/conf/locColl.yaml')
    (colls[sublib] and colls[sublib]['collections'][collection]) or
        colls[sublib]['desc']
  end
end


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
    Array(@doc['publishDate']).first
  end

  def pages
    candidate = marc['300'] && marc['300']['a']
    m         = /(\d+)\s*p/.match(candidate)
    m ? m[1] : candidate
  end

  def e_holdings
    [electronic_holdings, ht_holdings].flatten.compact.uniq
  end


  def to_h
    h         = {
        'id'                  => record_id,
        'catalog_url'         => catalog_url,
        'title'               => title,
        'languages'           => languages,
        'main_author'         => main_author,
        'other_authors'       => other_authors,
        'formats'             => formats,
        'pages'               => pages,
        'publication_date'    => publication_date,
        'print_holdings'      => print_holdings.map(&:to_h),
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
  set :mirlyn_solr_url, Settings.solr_url || ENV['MIRLYN_SOLR_URL']
  set :mirlyn_dev_solr_url, Settings.dev_solr_url || ENV['MIRLYN_DEV_SOLR_URL']
  set :client, MirlynIdApi::SolrClient.new(settings.mirlyn_solr_url)
  set :root, Settings.application_root || ENV['MIRLYN_API_APPLICATION_ROOT']
  set :default_encoding, 'utf-8'


  # Make sure json is sent with the charset (utf-8)
  settings.add_charset << 'application/json'


  helpers do
    def malformed!(type, val)
      status 400
      jsonp({'status' => status, 'error' => "'#{val}' cannot be interpreted as an #{type}"})
    end

    def kv_search(key, val)
      if request.query_string =~ /dev/i
        client = MirlynIdApi::SolrClient.new(settings.mirlyn_dev_solr_url)
      else
        client = settings.client
      end
      resp = client.kv_search(key, val)
      if resp.empty?
        status 404
        rv           = resp.to_h
        rv['status'] = 404
        jsonp rv
      else
        rv = resp
        rv.docs.map! { |x| MirlynDocumentPresenter.new(x) }

        rv = rv.to_h.merge({'status' => 200})

        rv['hostname'] = Socket.gethostname

        jsonp rv
      end
    end
  end


  get '/' do
    jsonp({'valid_keys' => {
        'id'   => 'Mirlyn Record ID',
        'issn' => "ISSN",
        'oclc' => 'OCLC Number',
        'isbn' => "ISBN",
        'lccn' => "Library of Congress Call Number",
        'htid' => "HathiTrust ID",
        "barcode" => "UM Barcode"
    }})
  end


  # For ISBNs, search on the given value and the 10/13 forms
  get '/isbn/:val' do
    val = params[:val]
    unless StdNum::ISBN.at_least_trying?(val)
      malformed!('isbn', val)
    else
      bestguess = StdNum::ISBN.reduce_to_basics(val, [10, 13])
      kv_search('isbn', '(' + [bestguess, StdNum::ISBN.allNormalizedValues(val)].flatten.compact.uniq.join(' OR ') + ')')
    end
  end

  get '/issn/:val' do
    val = params[:val]
    unless StdNum::ISSN.reduce_to_basics(val, 8)
      malformed!('issn', val)
    else
      kv_search('issn', val)
    end
  end

  get '/lccn/:val' do
    val        = params[:val]
    normalized = StdNum::LCCN.normalize(val)
    unless normalized
      malformed!('lccn', val)
    else
      kv_search('lccn', normalized)
    end
  end

  get '/id/:val' do
    val = params[:val]
    n   = val.gsub(/\D/, '')
    kv_search('id', n)
  end

  get '/oclc/:val' do
    val = params[:val]
    n   = val.gsub(/\D/, '')
    kv_search('oclc', n)
  end

  get '/htid/:val' do |htid|
    kv_search('ht_id', htid)
  end

  get '/barcode/:val' do |barcode| 
    kv_search('barcode', barcode)
  end

  # Catch all
  get '/:key/:val' do
    status 405
    jsonp({'status' => status, 'error' => "Search key '#{params[:key]}' is not supported"})
  end


  run! if app_file == $0
end
