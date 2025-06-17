# SURWC

Uma forma de criar servidores de forma fácil e rápida.

> O SURWC é um projeto que tem o propósito de criar servidores web de forma rápida, leve e sem dependências externas.

---

## 📦 Como usar?

Clone a pasta `lib` do projeto com:

```bash
git clone https://github.com/pedrodevelopagens/SURWC/lib
```

Depois, importe o módulo no seu código:

```ruby
require_relative "./lib/surwc"
```

Ou use o caminho onde está localizado o módulo do SURWC.

---

## 🚀 Criando o servidor

```ruby
server = SURWC::Server.new(port: 3000)
```

Você pode definir qualquer porta.

---

## 🔥 Rotas

### Definindo rotas simples:

```ruby
server.get '/hello' do |req|
  "Olá mundo!"
end
```

### Com parâmetros na URL:

```ruby
server.get '/users/:id' do |req|
  "ID do usuário: #{req[:params]['id']}"
end
```

> Acessando `http://localhost:3000/users/42` → Retorno: `ID do usuário: 42`

### Suporte a múltiplos métodos HTTP:

* `get`
* `post`
* `put`
* `delete`
* `patch`
* `options`

#### Exemplo POST:

```ruby
server.post '/enviar' do |req|
  "Você enviou: #{req[:body]}"
end
```

Se você enviar um JSON com:

```json
{"nome": "Pedro"}
```

O retorno será:

```
Você enviou: {"nome"=>"Pedro"}
```

---

## 🛡️ Middlewares

### Middleware global:

Executado em **todas as rotas**.

```ruby
server.use do |req|
  puts "[LOG] #{req[:method]} #{req[:path]}"
end
```

### Middleware por rota:

```ruby
auth = ->(req) do
  return "Acesso negado" unless req[:headers]["Authorization"] == "secreta"
end

server.get '/segredo', server.with_middleware(auth) do |req|
  "Acesso autorizado"
end
```

> Sem header `Authorization: secreta` → Retorno: `Acesso negado`
> Com header correto → Retorno: `Acesso autorizado`

---

## 🍪 Cookies

O SURWC possui um sistema de cookies simples e robusto.

### Pegando cookies:

```ruby
server.get '/meus_cookies' do |req|
  cookies = req[:cookies]
  "Seus cookies: #{cookies.to_hash}"
end
```

### Pegando um cookie específico:

```ruby
cookies.get('nome_do_cookie')
```

### Verificando se existe:

```ruby
cookies.has?('nome_do_cookie')
```

### Pegando todos em formato array:

```ruby
cookies.get_all
```

**Exemplo retorno:**

```ruby
[{"token"=>"abc123"}, {"usuario"=>"Pedro"}]
```

### Definindo cookies:

```ruby
server.get '/setar_cookie' do |req|
  req[:cookies].set('usuario', 'Pedro', { path: '/', max_age: 3600 })
  "Cookie setado!"
end
```

### Deletando cookies:

```ruby
server.get '/deletar_cookie' do |req|
  req[:cookies].delete('usuario')
  "Cookie deletado!"
end
```

---

## 📂 Arquivos estáticos

Coloque seus arquivos no diretório `public/`. Eles serão servidos automaticamente.

### Exemplo:

```
/public/index.html → http://localhost:3000/
```

---

## 🎨 Templates ERB

Você pode renderizar arquivos `.erb` com variáveis locais.

### Exemplo:

### `/public/sobre.erb`

```erb
<h1>Sobre <%= nome %></h1>
<p>Bem-vindo(a) ao nosso site!</p>
```

### Código:

```ruby
server.get '/sobre' do |req|
  server.send(:render, 'sobre.erb', { nome: "SURWC" })
end
```

### Resultado:

```
<h1>Sobre SURWC</h1>
<p>Bem-vindo(a) ao nosso site!</p>
```

---

## 🧠 Request (req)

O objeto `req` dentro de cada rota possui:

| Chave      | Descrição                                    |
| ---------- | -------------------------------------------- |
| `:method`  | Método HTTP (`GET`, `POST`, etc.)            |
| `:path`    | Caminho da requisição (`/hello`)             |
| `:query`   | Parâmetros da query string (`?id=1`)         |
| `:headers` | Headers HTTP                                 |
| `:params`  | Parâmetros da URL dinâmica (`/users/:id`)    |
| `:body`    | Corpo da requisição (JSON ou string)         |
| `:cookies` | Instância de `SURWC::Cookies` para manipular |

---

## 🖥️ Respostas

### Como retornar dados:

* Se retornar uma `String`, ela é enviada como HTML.
* Se retornar um objeto Ruby (`Hash`, `Array`, etc.), ele será convertido para JSON.

### Exemplo JSON:

```ruby
server.get '/dados' do |req|
  { status: 'ok', user: 'Pedro' }
end
```

> Retorno:

```json
{"status":"ok","user":"Pedro"}
```

---

## 🛑 Tratamento de erros

Se uma rota não for encontrada → resposta `404` com uma página de erro.
Se ocorrer um erro interno → resposta `500` com uma página de erro.

---

## 🚀 Iniciando o servidor

```ruby
server.start
```

O servidor ficará disponível em:

```
http://localhost:3000
```

Ou na porta que você definiu.

---

## 🧠 Recursos internos

### Métodos internos úteis:

* `render('arquivo.erb', locals = {})` → Renderiza um template ERB.
* Cookies:

  * `cookies.get('nome')`
  * `cookies.get_all`
  * `cookies.to_hash`
  * `cookies.has?('nome')`
  * `cookies.set('nome', 'valor', options)`
  * `cookies.delete('nome')`
* Middlewares globais → `server.use`
* Middlewares por rota → `server.with_middleware(auth)`

---

## 📜 Lista de métodos HTTP suportados:

| Método  | Suporte |
| ------- | ------- |
| GET     | ✅       |
| POST    | ✅       |
| PUT     | ✅       |
| DELETE  | ✅       |
| PATCH   | ✅       |
| OPTIONS | ✅       |

---

## 🏗️ Exemplo completo

```ruby
require_relative './lib/surwc'

server = SURWC::Server.new(port: 3000)

server.use do |req|
  puts "[LOG] #{req[:method]} #{req[:path]}"
end

server.get '/' do |req|
  "Bem-vindo ao SURWC"
end

server.get '/users/:id' do |req|
  "User ID: #{req[:params]['id']}"
end

server.post '/echo' do |req|
  "Você enviou: #{req[:body]}"
end

server.start
```

---

Feito com ❤️ pelo PedroDev!
