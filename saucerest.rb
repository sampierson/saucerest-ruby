require 'rubygems'
require 'rest_client'
require 'json'

module SauceREST

  # A simple class for using the Sauce Labs REST API
  class Client
    @@roots = {
      :script => 'scripts',
      :job => 'jobs',
      :result => 'results',
      :tunnel => 'tunnels'
    }

    def initialize base_url
      @base_url = base_url
      @resource = RestClient::Resource.new @base_url
    end

    def create type, *args
      doc = args[-1]
      doc_json = JSON.generate doc
      resp_json = @resource[@@roots[type]].post(doc_json,
                                                :content_type =>
                                                'application/octet-stream')
      resp = JSON.parse resp_json
      return resp
    end

    def get type, docid
      resp_json = @resource[@@roots[type] + '/' + docid].get
      resp = JSON.parse resp_json
      return resp
    end

    def attach docid, name, data
      resp_json = @resource[@@roots[:script] + '/' + docid + '/' + name].put data
      resp = JSON.parse resp_json
      return resp
    end

    def delete type, docid
      resp_json = @resource[@@roots[type] + '/' + docid].delete
      resp = JSON.parse resp_json
      return resp
    end

    def list type
      resp_json = @resource[@@roots[type] + '/'].get
      resp = JSON.parse resp_json
      return resp
    end
  end

end
