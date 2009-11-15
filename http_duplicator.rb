require 'rubygems'
require 'eventmachine'
require 'evma_httpserver'
require 'event_utils'
require 'json/add/core'

class Backend
  attr_reader :host, :port, :status, :headers, :content

  include EM::Deferrable

  def initialize(host, port)
    @host = host
    @port = port
  end

  def send_request(params)
     client = EventMachine::Protocols::HttpClient.request(params)

     client.callback {|response|
       @status = response[:status]
       @headers = response[:headers]
       @content = response[:content]
       self.succeed
     }
     client.errback { self.fail }
     return self
  end
end

class HTTP_Duplicator < EM::Connection
  include EM::HttpServer
  include EventUtils
  
  def post_init
    super
    no_environment_strings
  end

  def process_http_request
    backends = [
      Backend.new('localhost', 10001),
      Backend.new('localhost', 10002)
    ]

    in_deferred_loop do
      results = Array.new

      backends.each do |backend|
        results << backend.send_request(
          :host => backend.host,
          :port => backend.port,
          :request => @http_request_uri,
          :verb => @http_request_method,
          :content => @http_request_post_content,
          :contenttype => @http_content_type,
          :querystring => @http_query_string
        )
      end

      waiting_for(*results) do
        puts "Got all answers !"
        status_codes = Hash.new
        server_status = Hash.new

        results.each do |result|
          puts "* #{result.host}:#{result.port} - HTTP #{result.status}"
          server_status[result.host+':'+result.port.to_s] = result.status
          status_codes[result.status] = 0 unless status_codes[result.status]
          status_codes[result.status] += 1
        end

        # Send back response
        response = EM::DelegatedHttpResponse.new(self)
        if status_codes[200] and status_codes[200].size == results.size
          response.status = 200
        else
          response.status = 503
        end
        response.content = server_status.to_json
        response.content_type 'application/json'
        response.send_response
      end
    end
  end
end

EM::run do
  EM::start_server '127.0.0.1', 10000, HTTP_Duplicator
end
