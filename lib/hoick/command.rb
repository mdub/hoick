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

    option ["--debug"], :flag, "debug"

    class Redirected < StandardError

      def initialize(location)
        @location = location
        super("Redirected to #{location}")
      end

    end

    subcommand ["get", "GET"], "HTTP GET" do

      option ["--follow"], :flag, "follow redirects"

      declare_url_parameter

      def execute
        uri = full_url
        request = Net::HTTP::Get.new(uri.request_uri)
        with_http_connection(uri) do |http|
          http.request(request) do |response|
            if follow? && response.kind_of?(Net::HTTPRedirection)
              raise Redirected, response['location']
            else
              display_response(response)
            end
          end
        # rescue Redirected => e
        #   uri = e.location
        #   retry
        end
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
        uri = full_url
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = content_type
        request.body = payload
        with_http_connection(uri) do |http|
          http.request(request) do |response|
            display_response(response)
          end
        end
      end

    end

    subcommand ["put", "PUT"], "HTTP PUT" do

      include PayloadOptions

      declare_url_parameter

      def execute
        uri = full_url
        put = Net::HTTP::Put.new(uri.request_uri)
        put["Content-Type"] = content_type
        put.body = payload
        with_http_connection(uri) do |http|
          http.request(put) do |response|
            display_response(response)
          end
        end
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

    def with_http_connection(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.set_debug_output($stderr) if debug?
      http.start do
        yield http
      end
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

  end

end
