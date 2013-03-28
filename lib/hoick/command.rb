require "clamp"
require "net/http"

module Hoick

  class Command < Clamp::Command

    option ["-b", "--[no-]body"], :flag, "display response body", :default => true
    option ["-h", "--[no-]headers"], :flag, "display response status and headers"

    option ["--debug"], :flag, "debug"

    subcommand ["get", "GET"], "HTTP GET" do

      option ["-f", "--follow"], :flag, "follow redirects"

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

    subcommand ["put", "PUT"], "HTTP PUT" do

      parameter "URL", "address"
      parameter "[FILE]", "file to upload"

      def execute
        content = read_content
        with_connection_to(url) do |http, uri|
          put = Net::HTTP::Put.new(uri.request_uri)
          put.body = content
          put["Content-Type"] = "application/octet-stream"
          http.request(put) do |response|
            display_response(response)
          end
        end
      end

      def read_content
        if file
          File.read(file)
        else
          $stdin.read
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
