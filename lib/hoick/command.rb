require "clamp"
require "mime/types"
require "net/http"

module Hoick

  class Command < Clamp::Command

    class << self

      private

      def parse_url(url)
        URI(url)
      rescue ArgumentError => e
        raise e
      rescue URI::InvalidURIError => e
        raise ArgumentError, e.message
      end

      def declare_url_parameter
        parameter "URL", "address", &method(:parse_url)
      end

    end

    option ["--base-url"], "URL", "base URL", &method(:parse_url)

    option ["-b", "--[no-]body"], :flag, "display response body", :default => true
    option ["-h", "--[no-]headers"], :flag, "display response status and headers"

    option ["--timeout"], "SECONDS", "HTTP connection/read timeout", &method(:Float)

    option ["--debug"], :flag, "debug"

    def follow_redirects?
      false
    end

    subcommand ["get", "GET"], "HTTP GET" do

      option ["--follow"], :flag, "follow redirects", :attribute_name => :follow_redirects

      declare_url_parameter

      def execute
        get(full_url, &method(:display_response))
      end

      private

      def get(uri, &callback)
        http_request("GET", uri) do |response|
          if follow_redirects? && response.kind_of?(Net::HTTPRedirection)
            raise Redirected, response['location']
          end
          callback.call(response)
        end
      rescue Redirected => e
        uri = URI(e.location)
        retry
      end

      class Redirected < StandardError

        def initialize(location)
          @location = location
          super("Redirected to #{location}")
        end

        attr_reader :location

      end

    end

    subcommand ["head", "HEAD"], "HTTP HEAD" do

      declare_url_parameter

      def execute
        http_request("HEAD", full_url, nil, nil, &method(:display_response))
      end

    end

    module PayloadOptions

      extend Clamp::Option::Declaration

      option ["-F", "--file"], "FILE", "input file"
      option ["-T", "--content-type"], "TYPE", "payload Content-Type" do |arg|
        if arg.index("/")
          arg
        else
          mime_type_of(arg) || raise(ArgumentError, "unrecognised type: #{arg.inspect}")
        end
      end

      def payload
        if file
          File.read(file)
        else
          $stdin.read
        end
      end

      protected

      def default_content_type
        (mime_type_of(file) if file) ||  "application/octet-stream"
      end

      def mime_type_of(filename_or_ext)
        resolved_type = MIME::Types.of(filename_or_ext).first
        resolved_type.to_s if resolved_type
      end

    end

    subcommand ["post", "POST"], "HTTP POST" do

      include PayloadOptions

      declare_url_parameter

      def execute
        http_request("POST", full_url, payload, content_type, &method(:display_response))
      end

    end

    subcommand ["put", "PUT"], "HTTP PUT" do

      include PayloadOptions

      declare_url_parameter

      def execute
        http_request("PUT", full_url, payload, content_type, &method(:display_response))
      end

    end

    private

    def full_url
      if base_url
        base_url + url
      else
        url
      end
    end

    def http_request(method, uri, content = nil, content_type = nil, &callback)
      request = build_request(method, uri, content, content_type)
      with_http_connection(uri) do |http|
        http.request(request) do |response|
          if follow_redirects? && response.kind_of?(Net::HTTPRedirection)
            raise Redirected, response['location']
          end
          callback.call(response)
        end
      end
    rescue Redirected => e
      uri = URI(e.location)
      retry
    rescue SocketError, TimedOut => e
      $stderr.puts "ERROR: #{e}"
      exit(1)
    end

    def build_request(method, uri, content, content_type)
      request_class = Net::HTTP.const_get(method.to_s.capitalize)
      request = request_class.new(uri.request_uri)
      if content
        request["Content-Type"] = content_type
        request.body = content
      end
      request
    end

    def with_http_connection(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.set_debug_output($stderr) if debug?
      if timeout
        http.open_timeout = timeout
        http.read_timeout = timeout
      end
      http.start do
        begin
          yield http
        rescue Timeout::Error
          raise TimedOut, "request timed out"
        end
      end
    rescue Timeout::Error
      raise TimedOut, "connection timed out"
    end

    def display_response(response)
      if headers?
        puts "HTTP/#{response.http_version} #{response.code} #{response.message}"
        response.each_capitalized do |header, value|
          puts("#{header}: #{value}")
        end
        puts ""
      end
      if body?
        response.read_body do |chunk|
          print chunk
        end
      end
      unless response.kind_of?(Net::HTTPSuccess)
        exit(response.code.to_i / 100)
      end
    end

    class TimedOut < StandardError; end

  end

end
