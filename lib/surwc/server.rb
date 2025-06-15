# frozen_string_literal: true

require 'socket'
require 'cgi'
require 'json'
require 'erb'
require 'pathname'

module SURWC
  class Server
    def initialize(port: 4567, public_root: nil)
      @port = port
      @routes = { 'GET' => [], 'POST' => [], 'PUT' => [], 'DELETE' => [] }
      @global_middlewares = []
      @public_root = public_root || File.join(Dir.pwd, 'public')

      # Configuração UTF-8 para o ambiente
      Encoding.default_external = Encoding::UTF_8
      Encoding.default_internal = Encoding::UTF_8
    end

    def get(path, options = {}, &handler)
      add_route('GET', path, handler, options)
    end

    def post(path, options = {}, &handler)
      add_route('POST', path, handler, options)
    end

    def put(path, options = {}, &handler)
      add_route('PUT', path, handler, options)
    end

    def delete(path, options = {}, &handler)
      add_route('DELETE', path, handler, options)
    end

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
      pattern = path.gsub(%r{/:(\w+)}) { keys << $1; '/([^/]+)' }
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

        route = @routes[method]&.find { |r| r[:pattern].match(path) } or
          return send_response(client, 404, 'Not Found')

        extract_params(req, route)
        run_middlewares(req, route)

        response = route[:handler].call(req)
        content = response.is_a?(String) ? response : response.to_json
        send_response(client, 200, content)
      rescue => e
        send_response(client, 500, e.message)
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
        JSON.parse(raw_body) rescue raw_body
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

    def send_response(client, status, body, headers = {})
      # Configura headers padrão com UTF-8
      default_headers = {
        'Content-Type' => 'text/html; charset=utf-8',
        'Content-Length' => body.to_s.bytesize
      }

      # Mescla headers personalizados mantendo o charset UTF-8
      merged_headers = default_headers.merge(headers) do |key, oldval, newval|
        key.casecmp?('content-type') && !newval.include?('charset=') ?
          "#{newval}; charset=utf-8" : newval
      end

      # Monta a resposta HTTP
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

    def try_serve_static(req, res)
      path = req[:path] == '/' ? 'index.html' : req[:path][1..]
      static_file = File.join(@public_root, path)

      if File.exist?(static_file) && !File.directory?(static_file)
        res.send(render(path))
        true
      else
        false
      end
    end
  end
end
