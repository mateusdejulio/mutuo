# Melhorias do Mútuo

Lista de melhorias levantadas numa análise do código em outubro de 2026, em ordem de prioridade. Cada item diz **o problema**, **onde está** e **como resolver**. Marque o checkbox quando terminar.

Os arquivos são citados pelo nome da função ou da rota, e não pelo número da linha, porque as linhas mudam com o tempo.

---

## 1. Segurança (fazer primeiro)

### 1.1 Autenticação por token na API
- [ ] **Problema:** a API não sabe quem está fazendo cada chamada. O login devolve os dados da conta, o front guarda no `sessionStorage`, e as outras rotas recebem o CPF ou o CNPJ no body ou na URL. Quem souber o CPF de alguém consegue editar o perfil, criar serviços ou ler conversas no nome dessa pessoa.
- **Onde:** `mutuo-api/index.js` (todas as rotas que recebem `cpf`/`cnpj`), `web/` (todas as páginas que leem `usuarioLogado`/`ongLogada`), `mobile/mutuo/lib/services/api_service.dart` e `auth_service.dart`.
- **Como:**
  1. No `/loginUsuario` e no `/loginOng`, gerar um token assinado com `{ tipo, id }` e validade de alguns dias. O `jsonwebtoken` é o padrão. Sem dependência nova, dá para fazer um token HMAC com o `crypto` nativo.
  2. Criar um middleware `autenticar` que lê `Authorization: Bearer <token>`, valida e coloca `req.conta = { tipo, id }`.
  3. Nas rotas protegidas, usar `req.conta.id` em vez do CPF/CNPJ que vem do cliente.
  4. No web, guardar o token e mandar no header em todo `fetch`. No Flutter, guardar no `shared_preferences` e adicionar no `_headers` do `ApiService`.
  5. No Socket.IO, mandar o token no `auth` da conexão e validar no `io.use(...)`, em vez de confiar no evento `identificar`.
- **Cuidado:** migrar rota por rota e testar cada tela. É a mudança mais trabalhosa da lista, mas é a mais importante.

### 1.2 Senha do administrador com bcrypt
- [ ] **Problema:** o `validarLogin` (em `db.js`) compara a senha do admin em texto puro: `WHERE login = ? AND senha = ?`. Quem tiver acesso ao banco vê as senhas.
- **Como:** buscar o admin só pelo `login` e comparar com o `verificarSenha`, que já existe e migra senhas antigas para hash sozinho, como acontece com usuários e ONGs. Conferir também o `cadastrarAdm` e o `alterarSenhaAdm`, para que gravem com `bcrypt.hash(senha, 10)`.

### 1.3 Rotas que expõem dados de todos
- [ ] **Problema:** o `GET /usuarios` devolve CPF, nome e e-mail de **todos** os usuários para qualquer pessoa. Existem outras listagens no mesmo estilo (`/ongs`, solicitações etc.).
- **Como:** depois do item 1.1, deixar essas rotas só para o admin. Revisar cada `app.get` e se perguntar: "quem pode ver isso?".

### 1.4 Painel Electron sem acesso direto ao banco
- [ ] **Problema:** o Electron importa o `db.js` e conecta direto no MySQL. A senha do banco vai junto com o programa instalado, e o banco precisa ficar aberto para qualquer IP.
- **Como:** criar rotas de admin na API (protegidas pelo login de admin com token) e fazer o painel chamar a API com `fetch`, como o site já faz.

### 1.5 Limite de tentativas
- [ ] **Problema:** `/login`, `/loginUsuario`, `/loginOng`, `/esqueciSenha` e `/verificarCodigo` aceitam tentativas sem limite por IP. Isso permite chutar senhas ou disparar muitos e-mails do Brevo.
- **Como:** um `Map` em memória com `ip → { contagem, inicio }`, por exemplo 10 tentativas a cada 15 minutos, respondendo `429` com mensagem em JSON. Se puder usar dependência, o `express-rate-limit` resolve. No Render, ligar `app.set('trust proxy', 1)` para pegar o IP real.

### 1.6 Escapar HTML no e-mail de contato
- [ ] **Problema:** na rota `/contato`, o `nome`, o `email` e a `mensagem` entram direto no HTML do e-mail. Alguém pode mandar HTML ou links disfarçados para a caixa da equipe.
- **Como:** criar uma função `escaparHtml` (trocar `& < > " '` por entidades) e aplicar nos três campos antes de montar o `html`.

### 1.7 Não vazar erro interno
- [ ] **Problema:** o middleware de erro global no fim do `index.js` responde `err.message` para o cliente, o que pode mostrar detalhes do banco ou do código.
- **Como:** manter o `console.error` com o erro completo e responder uma mensagem genérica. Exceções conhecidas, como o erro de tamanho do Multer, podem continuar com mensagem específica.

### 1.8 CORS restrito
- [ ] **Problema:** o `app.use(cors())` aceita qualquer origem.
- **Como:** passar `origin` com a lista dos domínios do site. O app Flutter não é afetado, porque CORS só vale para navegador.

---

## 2. Estabilidade e manutenção

### 2.1 Evitar o cold start do Render
- [ ] **Problema:** no plano gratuito, a API "dorme" depois de cerca de 15 minutos sem uso, e a primeira chamada demora. Isso é ruim em apresentação.
- **Como:** criar uma rota leve `GET /saude` que responde `{ ok: true }` e cadastrar no **UptimeRobot** (gratuito) um ping a cada 10 minutos. Lembrar de ligar antes de apresentações.

### 2.2 Certificados mais leves
- [ ] **Problema:** cada certificado abre um Chrome inteiro com o Puppeteer, o que é pesado para a memória do plano gratuito.
- **Como:** salvar o PDF gerado (por exemplo em `cache/`, pelo código de verificação) e devolver o arquivo salvo nos próximos pedidos. Também dá para manter um único `browser` aberto e reaproveitar entre pedidos, em vez de abrir e fechar a cada vez.

### 2.3 Dividir os arquivos grandes
- [ ] **Problema:** o `index.js` tem cerca de 1.400 linhas e o `db.js` cerca de 2.400. Fica difícil achar as coisas, e duas pessoas mexendo ao mesmo tempo geram conflito de merge.
- **Como:** criar `routes/` com um `express.Router` por assunto (`auth`, `usuarios`, `ongs`, `servicos`, `solicitacoes`, `chat`, `certificados`, `premium`) e `repositorios/` com as funções de banco correspondentes. Mover aos poucos, um assunto por commit.

### 2.4 Um padrão só para criar tabelas
- [ ] **Problema:** existem a pasta `migrations/` (rodada à mão) e o `inicializarTabelas` (roda sozinho no boot).
- **Como:** escolher um padrão. A sugestão é fazer o boot rodar as migrations pendentes e registrar as que já rodaram numa tabela `Mutuo_Migracao`.

### 2.5 Pequenas limpezas
- [ ] O `module.exports` do `db.js` repete `contarVoluntariosOng` e `isOngPremium`. Basta apagar as duplicatas.
- [ ] O site carrega três versões do Bootstrap (5.3.2, 5.3.3 e 5.3.8). Padronizar numa só.
- [ ] As pastas `web/usuárioComum` e `web/usuárioOng` têm acento no nome, o que pode quebrar URLs em alguns servidores. Renomear para `usuarioComum`/`usuarioOng` e atualizar os links.
- [ ] As imagens estão duplicadas em `web/imagens` e `web/usuárioComum/imagens`. Deixar uma pasta só.

### 2.6 Testes automáticos
- [ ] **Problema:** não há nenhum teste. Qualquer mudança só é conferida na mão.
- **Como:** usar o `node:test` nativo (sem dependência) em `mutuo-api/test/`. Começar pelo que é crítico e tem lógica própria: `rules.js` da moderação, a validação de senha e o fluxo de recuperação de senha. No Flutter, o `flutter_test` já está no projeto.

---

## 3. Funcionalidades novas

### 3.1 Confirmação de e-mail no cadastro
- [ ] Ao cadastrar, mandar um código de 6 dígitos pelo Brevo e só ativar a conta depois de confirmar. Dá para reaproveitar quase tudo da recuperação de senha: a tabela de códigos com hash, o `enviarEmailBrevo`, o `htmlEmailCodigo` e a tela com as 6 caixas.

### 3.2 Camada 3 da moderação
- [ ] O `moderation/policy.js` já lista as categorias próprias do Mútuo (`FRAUDE`, `DROGAS`, `ARMAS`, `PIRATARIA`, `SPAM`, `FORA_DO_ESCOPO`...), mas o `moderationService.js` ainda não usa. Implementar como um segundo prompt ao Gemini, com a política do Mútuo, e incluir esses casos no `testar-moderacao.js` (o caso 5, de atestado falso, já está lá esperando).

### 3.3 QR code no certificado
- [ ] Colocar no PDF um QR code que abre o `verificarCertificado.html` com o código de verificação já preenchido. Dá para gerar a imagem por uma API pública de QR code, ou com o pacote `qrcode` se puder adicionar dependência.

### 3.4 E-mails de eventos importantes
- [ ] Usar o Brevo para avisar por e-mail quando uma solicitação for aceita ou recusada, quando receber uma avaliação ou quando o certificado ficar pronto. Complementa o push para quem não está com o app instalado.

### 3.5 LGPD: excluir conta e baixar dados
- [ ] Botão "Excluir minha conta" (com confirmação por senha) e "Baixar meus dados" (JSON com perfil, serviços e solicitações). Costuma contar ponto em banca de projeto.

### 3.6 Push no iPhone
- [ ] O app só tem o `google-services.json` do Android. Para o FCM funcionar no iOS, falta registrar o app iOS no Firebase, adicionar o `GoogleService-Info.plist` e configurar a chave APNs.

### 3.7 Site instalável (PWA)
- [ ] Adicionar `manifest.json` e um service worker simples no `web/`. Assim o site pode ser instalado no celular e mostrar uma tela "Conectando ao servidor..." durante o cold start, em vez de uma página em branco.

---

## Ordem sugerida

1. **1.2** Senha do admin com bcrypt (rápido e fecha um risco grande).
2. **1.6** e **1.7** Escape no contato e erro genérico (pequenos).
3. **2.1** Ping para o cold start (5 minutos e melhora as apresentações).
4. **1.1** Token de autenticação (o maior, depois dele vêm o 1.3 e o 1.4).
5. O resto conforme o tempo e o interesse da equipe.
