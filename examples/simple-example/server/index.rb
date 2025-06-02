# frozen_string_literal: true

require_relative '../lib/surwc'

server = SURWC::Server.new(port: 3000)

# Middleware global
server.use do |req|
  puts "[#{Time.now}] #{req[:method]} #{req[:path]}"
end

# Hello World normal
server.get '/' do |_req|
  'Olá mundo! 🌍✨'
end

# Rota com parâmetros
server.get '/hello/:name' do |req|
  "Eae #{req[:params]['name'].capitalize}!"
end

# POST com JSON
server.post '/api/data' do |req|
  data = req[:body]
  "Vce enviou isso aqui: #{data.to_json} de jason"
end

# Middleware para apenas uma rota
logger_middleware = proc do |req|
  puts "Rota nada especial acessada por: #{req[:headers]['User-Agent']}"
end

server.get '/especial', server.with_middleware(logger_middleware) do |_req|
  'Você realmente nao e especial'
end

# Rodar o servidor
server.start
