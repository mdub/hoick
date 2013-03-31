require "clamp"
require "mime/types"
require "net/http"

module Hoick

  class Command < Clamp::Command

    option ["-b", "--[no-]body"], :flag, "display response body", :default => true
    option ["-h", "--[no-]headers"], :flag, "display response status and headers"

    option ["--debug"], :flag, "debug"

    subcommand ["get", "GET"], "HTTP GET" do

      option ["--follow"], :flag, "follow redirects"

      parameter "URL", "address"

      def execute
        get_with_redirects(url) do |response|
          display_response(response)
        end
      end

      def get_with_redirects(url, &callback)
        with_connection_to(url) do |http, uri|
          http.request_get(uri.request_uri) do |response|
            if follow? && response.kind_of?(Net::HTTPRedirection)
              get_with_redirects(response['location'], &callback)
            else
              callback.call(response)
            end
          end
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

      parameter "URL", "address"

      def execute
        content = payload
        with_connection_to(url) do |http, uri|
          post = Net::HTTP::Post.new(uri.request_uri)
          post["Content-Type"] = content_type
          post.body = content
          http.request(post) do |response|
            display_response(response)
          end
        end
      end

    end

    subcommand ["put", "PUT"], "HTTP PUT" do

      include PayloadOptions

      parameter "URL", "address"

      def execute
        content = payload
        with_connection_to(url) do |http, uri|
          put = Net::HTTP::Put.new(uri.request_uri)
          put["Content-Type"] = content_type
          put.body = content
          http.request(put) do |response|
            display_response(response)
          end
        end
      end

    end

    private

    def with_connection_to(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.set_debug_output($stderr) if debug?
      http.start do
        yield http, uri
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
