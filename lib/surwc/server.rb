# frozen_string_literal: true

require 'socket'
require 'cgi'
require 'json'
require 'erb'
require 'pathname'
require 'time'

module SURWC
  class Cookies
    def initialize(req)
      @req = req
      @cookies = parse_cookies(req[:headers]['Cookie'])
      @cookies_to_set = []
    end

    def parse_cookies(cookie_header)
      return {} unless cookie_header
      cookie_header.split('; ').map { |c| c.split('=', 2) }.to_h.transform_values { |v| CGI.unescape(v) }
    end

    def get(name = nil)
      return @cookies if name.nil?
      @cookies[name]
    end

    def get_all
      @cookies.map { |key, value| { key => value } }
    end

    def to_hash
      @cookies.dup
    end

    def has?(name)
      @cookies.key?(name)
    end

    def set(name, value, options = {})
      cookie = build_cookie(name, value, options)
      @cookies_to_set << cookie
    end

    def delete(name, options = {})
      set(name, '', options.merge(max_age: 0))
    end

    def cookies_to_set
      @cookies_to_set
    end

    private

    def build_cookie(name, value, options = {})
      cookie = "#{name}=#{CGI.escape(value.to_s)}"
      cookie << "; Path=#{options[:path]}" if options[:path]
      cookie << "; Domain=#{options[:domain]}" if options[:domain]
      cookie << "; Max-Age=#{options[:max_age]}" if options[:max_age]
      cookie << "; Expires=#{options[:expires].httpdate}" if options[:expires]
      cookie << "; HttpOnly" if options[:httponly]
      cookie << "; Secure" if options[:secure]
      cookie << "; SameSite=#{options[:samesite]}" if options[:samesite]
      cookie
    end
  end

  class Server
    def initialize(port: 4567, public_root: nil)
      @port = port
      @routes = { 'GET' => [], 'POST' => [], 'PUT' => [], 'DELETE' => [], 'PATCH' => [], 'OPTIONS' => [] }
      @global_middlewares = []
      @public_root = public_root || File.join(Dir.pwd, 'public')

      Encoding.default_external = Encoding::UTF_8
      Encoding.default_internal = Encoding::UTF_8
    end

    def get(path, options = {}, &handler)     = add_route('GET', path, handler, options)
    def post(path, options = {}, &handler)    = add_route('POST', path, handler, options)
    def put(path, options = {}, &handler)     = add_route('PUT', path, handler, options)
    def delete(path, options = {}, &handler)  = add_route('DELETE', path, handler, options)
    def patch(path, options = {}, &handler)   = add_route('PATCH', path, handler, options)
    def options(path, options = {}, &handler) = add_route('OPTIONS', path, handler, options)

    def use(&middleware)
      @global_middlewares << middleware
    end

    def with_middleware(*middlewares)
      { middlewares: middlewares }
    end

    def start
      server = TCPServer.new(@port)
      puts "🚀 SURWC rodando em http://localhost:#{@port}"

      loop do
        client = server.accept
        Thread.new(client) { |conn| handle_request(conn) }
      end
    end

    private

    def add_route(method, path, handler, options = {})
      pattern, keys = compile_path(path)
      @routes[method] << {
        pattern: pattern,
        keys: keys,
        handler: handler,
        middlewares: options[:middlewares] || []
      }
    end

    def compile_path(path)
      keys = []
      pattern = path.gsub(%r{/:(\w+)}) do
        keys << Regexp.last_match(1)
        '/([^/]+)'
      end
      [Regexp.new("^#{pattern}$"), keys]
    end

    def handle_request(client)
      request_line = client.gets or return client.close

      begin
        method, full_path = request_line.split
        path, query = full_path.split('?', 2)

        headers = parse_headers(client)

        req = {
          method: method,
          path: path,
          query: query ? CGI.parse(query).transform_values(&:first) : {},
          headers: headers,
          params: {},
          body: parse_body(client, method, headers)
        }

        req[:cookies] = Cookies.new(req)

        route = @routes[method]&.find { |r| r[:pattern].match(path) }

        if route.nil?
          return send_response(client, 404, render_error_page(404, 'Página não encontrada'))
        end

        extract_params(req, route)
        run_middlewares(req, route)

        response = route[:handler].call(req)
        content = response.is_a?(String) ? response : response.to_json

        send_response(client, 200, content, {}, req[:cookies])
      rescue => e
        send_response(client, 500, render_error_page(500, e.message))
      ensure
        client.close
      end
    end

    def parse_headers(client)
      headers = {}
      while (line = client.gets) && line != "\r\n"
        key, value = line.split(': ', 2)
        headers[key] = value.strip if key
      end
      headers
    end

    def parse_body(client, method, headers)
      return unless %w[POST PUT PATCH].include?(method)

      length = headers['Content-Length'].to_i
      return unless length.positive?

      raw_body = client.read(length)

      if headers['Content-Type']&.include?('application/json')
        begin
          JSON.parse(raw_body)
        rescue
          raw_body
        end
      else
        raw_body
      end
    end

    def extract_params(req, route)
      match = route[:pattern].match(req[:path])
      route[:keys].each_with_index do |key, i|
        req[:params][key] = CGI.unescape(match[i + 1])
      end
    end

    def run_middlewares(req, route)
      @global_middlewares.each { |mw| mw.call(req) }
      route[:middlewares].each do |mw|
        result = mw.call(req)
        return result if result.is_a?(String)
      end
      nil
    end

    def send_response(client, status, body, headers = {}, cookies = nil)
      default_headers = {
        'Content-Type' => 'text/html; charset=utf-8',
        'Content-Length' => body.to_s.bytesize
      }

      if cookies
        cookie_headers = cookies.cookies_to_set.map { |c| ["Set-Cookie", c] }.to_h
        headers = headers.merge(cookie_headers)
      end

      merged_headers = default_headers.merge(headers) do |key, _oldval, newval|
        if key.casecmp?('content-type') && !newval.include?('charset=')
          "#{newval}; charset=utf-8"
        else
          newval
        end
      end

      response = "HTTP/1.1 #{status}\r\n"
      merged_headers.each { |k, v| response << "#{k}: #{v}\r\n" }
      response << "\r\n#{body}"

      client.print(response)
    end

    def render(file, locals = {})
      full_path = File.join(@public_root, file)
      raise "File not found: #{file}" unless File.exist?(full_path)

      content = File.read(full_path)
      if file.end_with?('.erb')
        ERB.new(content).result_with_hash(locals)
      else
        content.force_encoding(Encoding::UTF_8)
      end
    end

    def render_error_page(code, message)
      <<~HTML
        <!DOCTYPE html>
        <html lang="pt-br">
        <head>
          <meta charset="UTF-8">
          <title>Erro #{code}</title>
          <style>
            body { background: #111; color: #eee; font-family: sans-serif; text-align: center; padding: 5em; }
            h1 { font-size: 4em; margin-bottom: 0.5em; }
            p { color: #888; }
          </style>
        </head>
        <body>
          <h1>Erro #{code}</h1>
          <p>#{message}</p>
        </body>
        </html>
      HTML
    end
  end
end
