# SURWC
Uma forma de criar servidores de forma fácil e rápida

---

O SURWC é um projeto que tem o propósito de criar servidores web de forma rápida, leve e sem dependências externas.

## Como usar?

Clone a pasta `lib` do projeto com:

```bash
git clone https://github.com/pedrodevelopagens/SURWC/lib
````

Depois, importe o módulo no seu código:

```ruby
require_relative "./lib/surwc"
```

Ou use o caminho onde está localizado o módulo do SURWC.

Em seguida, crie o servidor com:

```ruby
server = SURWC::Server.new(port: 3000)
```

Você pode configurar a porta como quiser.

## Definindo rotas

```ruby
server.get '/hello' do |req|
  "Olá mundo!"
end

server.post '/data' do |req|
  "Você enviou: #{req[:body]}"
end
```

Com parâmetros:

```ruby
server.get '/users/:id' do |req|
  "ID do usuário: #{req[:params]['id']}"
end
```

## Middlewares

Middleware global:

```ruby
server.use do |req|
  puts "[LOG] #{req[:method]} #{req[:path]}"
end
```

Middleware por rota:

```ruby
auth = ->(req) do
  return "Acesso negado" unless req[:headers]["Authorization"] == "secreta"
end

server.get '/segredo', server.with_middleware(auth) do |req|
  "Acesso autorizado"
end
```

## Arquivos estáticos

Crie um diretório `public/` e coloque arquivos como `index.html`. Eles serão servidos automaticamente:

```
/public/index.html => http://localhost:3000/
```

## Templates ERB

Arquivos `.erb` podem ser renderizados com variáveis:

```ruby
server.get '/sobre' do |req|
  server.send(:render, 'sobre.erb', { nome: "SURWC" })
end
```

## Iniciar o servidor

```ruby
server.start
```

O servidor vai rodar em `http://localhost:3000` (ou a porta que você definir).

---

Feito com ❤️ por PedroDev