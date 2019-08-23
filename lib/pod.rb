require 'sinatra/base'
require 'sinatra/jsonp'
require 'json'
require 'mirlyn_id_api'

module PodSupport

  # A simple class to deal with HT Items as encoded in the 974
  class HTItem
    attr_accessor :rights, :htid, :pages, :ec, :updated

    def initialize(marc_field)
      @rights  = marc_field['r']
      @htid    = marc_field['u']
      @updated = marc_field['d'] && marc_field['d'].to_i
      @ec      = marc_field['z']
      @pages   = marc_field['p'] && marc_field['p'].to_i
    end
  end

  # A single solr document that exposes what we need from the MirlynSolrDocument
  class PodDocument < MirlynIdApi::MirlynSolrDocument
    def initialize(mdoc)
      @doc = mdoc.solr_doc_hash
      @ht_items = {}
    end

    def author
      [@doc['mainauthor'], @doc['author']].flatten.first
    end

    def ht_item(key)
      ht_items[key]
    end

    def ht_items
      if @ht_items.empty?
        marc.fields('974').each do |f|
          item                 = HTItem.new(f)
          @ht_items[item.htid] = item
        end
      end
      @ht_items
    end

  end
end

class PodNotFoundError < RuntimeError; end

class PodAPI < Sinatra::Base

  helpers Sinatra::Jsonp

  enable :logging
  enable :prefixed_redirects
  set :client, MirlynIdApi::SolrClient.new(Settings.solr_url || ENV['MIRLYN_SOLR_URL'])
  set :root, Settings.application_root || ENV['MIRLYN_API_APPLICATION_ROOT']

  helpers do
    def htid_search(val)
      val.strip!
      resp = settings.client.kv_search('ht_id', val)
      raise PodNotFoundError.new if resp.empty?

      # There can be only one document
      doc = PodSupport::PodDocument.new(resp.docs.first)
      item = doc.ht_item(val)
      rv = {
          'title' => doc.title,
          'author' => doc.author,
          'record_id' => doc.id,
          'htid' => item.htid,
          'pages' => item.pages,
          'enumchron' => item.ec,
          'rights_code' => item.rights,
          'last_updated' => item.updated
      }
      jsonp rv.merge({'status' => 200})
    rescue PodNotFoundError => e
      status 404
      rv           = resp.to_h
      rv['error'] = e.to_s
      rv['htid'] = val
      rv['status'] = 404
      jsonp rv
    end
  end

  get '/htid/:htid' do |htid|
    htid_search(htid)
  end

end
