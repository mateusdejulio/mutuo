# Levantamento de Funcionalidades — Mútuo

Data do levantamento: 2026-10-14
Commit analisado: 59c620a

> Levantamento feito por leitura do código (somente leitura). Nenhum arquivo do projeto foi alterado.
> Valores de `.env`, chaves e credenciais **não** foram transcritos; só os nomes das variáveis.
> Pastas ignoradas: `node_modules/`, `build/`, `.dart_tool/`, `dist/`, `mutuo-api/.cache/` (binários do Puppeteer), imagens e arquivos gerados.

---

## 1. Visão geral da arquitetura

### 1.1 Plataformas e tecnologias

| Plataforma | Pasta | Tecnologias (versões declaradas) |
|---|---|---|
| **API** | `mutuo-api/` | Node.js + Express `^5.2.1`, MySQL via `mysql2 ^3.22.5`, `bcryptjs ^3.0.3`, `cors ^2.8.6`, `dotenv ^17.4.2`, `multer ^2.1.1` (upload), `socket.io ^4.8.3` (tempo real), `firebase-admin ^14.3.0` (push), `puppeteer ^25.6.0` (PDF), `qrcode ^1.5.4`. E-mail pela API HTTP do Brevo (`fetch` nativo). Moderação pela API HTTP do Google Gemini (`fetch` nativo). Sem `package.json` com `scripts`/`version`. |
| **Web** | `web/` | HTML + CSS + JavaScript puro. Bootstrap (5.3.2, 5.3.3 e 5.3.8 carregados em páginas diferentes via CDN), Bootstrap Icons 1.11.1, SweetAlert2 11, Socket.IO client 4.7.5 (CDN), Google Fonts (Quicksand). **Não há PHP** no repositório. |
| **Desktop** | `electron/` | Electron `^28.3.3`, Chart.js `^4.5.1`, SweetAlert2 `^11.26.3`, Bootstrap (arquivo local `bootstrap.min.css/js`). |
| **Mobile** | `mobile/mutuo/` | Flutter, Dart SDK `^3.11.0`, versão do app `1.0.0+1`. Pacotes: `http ^1.6.0`, `shared_preferences ^2.3.2`, `image_picker ^1.2.3`, `url_launcher ^6.3.1`, `google_fonts ^6.2.1`, `mask_text_input_formatter ^2.9.0`, `flutter_svg ^2.0.10`, `socket_io_client ^3.1.6`, `flutter_local_notifications ^22.3.0`, `firebase_core ^4.14.0`, `firebase_messaging ^16.6.0`, `flutter_localizations` (pt_BR). |
| Banco | — | MySQL. **Não há script SQL de criação das tabelas principais no repositório**; só migrations parciais (`mutuo-api/migrations/`) e criação automática de algumas tabelas/colunas em `db.inicializarTabelas()` (ver seção 7). |

### 1.2 Comunicação com a API
- **Web**: `fetch` para `https://mutuo-api.onrender.com` (em `funcoes.js` usa `http://localhost:3000` quando a página roda em `localhost`; várias páginas têm a URL do Render fixa no código). Sessão guardada no `sessionStorage` (`usuarioLogado` ou `ongLogada`). Chat e badges por Socket.IO (`web/chat-socket.js`).
- **Mobile**: classe `ApiService` (`lib/services/api_service.dart`) com `baseUrl = 'https://mutuo-api.onrender.com'`. Sessão em `shared_preferences` (`AuthService`). Socket.IO (`ChatSocketService`), notificações locais e push FCM.
- **Desktop**: o processo principal (`electron/main.js`) faz `fetch` para `https://mutuo-api.onrender.com`, enviando `Authorization: Bearer <token>` do administrador; as telas acessam via `window.api` (`preload.js` + `ipcMain.handle`). O Electron **não** acessa mais o banco diretamente.
- **Tempo real**: Socket.IO no mesmo servidor HTTP da API. Eventos: `identificar`, `mensagem:enviar`, `mensagem:nova`, `mensagem:enviada`, `conversa:lida`, `solicitacao:nova`, `solicitacao:atualizada`.

### 1.3 Serviços externos
| Serviço | Uso |
|---|---|
| **Render** | Hospedagem da API (`mutuo-api.onrender.com`). A API faz auto-ping em `/health` a cada 10 min para reduzir o "sono" do plano gratuito. |
| **MySQL** (host externo, configurado por variável) | Banco de dados. |
| **Brevo** (API HTTP) | E-mails transacionais: código de confirmação de cadastro, código de recuperação de senha, formulário de contato, envio dos dados da conta (LGPD) em anexo. |
| **Firebase Cloud Messaging** | Push para o app Android (mensagens de chat e solicitações). Só há `google-services.json` do Android. |
| **Google Gemini** (API `generativelanguage.googleapis.com`) | Moderação automática de serviços (camadas 2 e 3), modelos `gemini-3.6-flash` e reserva `gemini-3.1-flash-lite`. |
| **ViaCEP** | Preenchimento automático de endereço por CEP (Web, Mobile, Desktop). |
| **Puppeteer (Chrome headless)** | Geração do certificado em PDF na API. |

### 1.4 Variáveis de ambiente (somente nomes)
Lidas pelo código da API: `DB_HOST`, `DB_USER`, `DB_PASS`, `DB_NAME`, `PORT`, `ADMIN_TOKEN_SECRET`, `SITE_URL_PUBLICA`, `API_URL_PUBLICA`, `BREVO_API_KEY`, `EMAIL_REMETENTE`, `NOME_REMETENTE`, `EMAIL_CONTATO`, `GEMINI_API_KEY`.
Presentes no `.env` versionado, mas **não lidas** pelo código atual: `EMAIL_USER`, `EMAIL_PASS`.
A `GEMINI_API_KEY` fica em `mutuo-api/.env.local` (ignorado pelo Git); o `db.js` carrega `.env.local` com prioridade sobre `.env`.

---

## 2. Perfis de usuário

Os perfis no código são definidos pelo **tipo de conta** (`'usuario'` / `'ong'`, tabelas `Mutuo_Usuario` / `Mutuo_ONG`), pela tabela `Mutuo_Adm` (administrador) e pela coluna `premium` (0/1).

| Perfil | Como o código identifica | O que pode fazer | Plataformas |
|---|---|---|---|
| **Visitante** (não autenticado) | Sem sessão | Ver a landing page, cadastrar-se, confirmar e-mail, recuperar senha, verificar autenticidade de certificado. | Web, Mobile (telas de abertura/cadastro/login) |
| **Usuário (comum)** | `tipo = 'usuario'`, chave `cpf` (`Mutuo_Usuario`) | Editar perfil e foto; cadastrar/editar/excluir até 3 serviços; buscar serviços de outros usuários e atividades de ONGs; solicitar serviços e participar de atividades de ONGs; aceitar/recusar solicitações recebidas; confirmar realização e avaliar; chat; notificações; certificados (PDF); planos/Premium; contato; exportar dados e excluir conta. Começa com 20 pontos. | Web, Mobile |
| **Administrador de ONG** | `tipo = 'ong'`, chave `cnpj` (`Mutuo_ONG`). A conta é da ONG; o responsável fica em `nomeResponsavel`. | Editar perfil e foto; cadastrar/editar/excluir até 5 atividades; receber e aceitar/recusar interesses de voluntários; confirmar realização (Web) e avaliar; chat; notificações; certificados emitidos; planos/Premium; exportar dados e excluir conta. Recebe bônus mensal de 500 pontos (se tiver até 1000). | Web, Mobile |
| **Administrador do Sistema** | Registro em `Mutuo_Adm` (login/senha); token HMAC de 12 h | Dashboard; gerenciar usuários, ONGs, serviços (de usuários), solicitações (entre usuários) e contas Premium; fila de revisão da moderação por IA; alterar login/senha; cadastrar outro administrador; modo escuro. | Desktop |
| **Usuário Premium** | `Mutuo_Usuario.premium = 1` | Tudo do Usuário comum + até 8 serviços ativos; seus serviços aparecem em "Vagas em destaque" e "Perto de você". | Web, Mobile |
| **ONG Premium** | `Mutuo_ONG.premium = 1` | Tudo da ONG + até 10 atividades ativas; atividades aparecem em "Vagas em destaque" e "Perto de você" dos usuários; selo "ONG verificada" na home do app. | Web, Mobile |

Não foram encontrados outros perfis no código.

---

## 3. Resumo (tabela)

Legenda: W = Web, M = Mobile, D = Desktop, A = API. ✔ = existe na plataforma; — = não existe.

| # | Funcionalidade | Perfis | Web | Mobile | Desktop | API | Status | Já documentada? |
|---|---|---|---|---|---|---|---|---|
| 4.1 | Cadastrar Usuário | Visitante, Adm. Sistema | ✔ | ✔ | ✔ | ✔ | ✅ | 2.5.4 / 2.9 |
| 4.2 | Cadastrar ONG | Visitante, Adm. Sistema | ✔ | ✔ | ✔ | ✔ | ✅ | 2.5.1 / 2.9 |
| 4.3 | Confirmação de e-mail no cadastro | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | Nova |
| 4.4 | Login (Usuário e ONG) | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | 2.5.12 / 2.9 |
| 4.5 | Login do Administrador | Adm. Sistema | — | — | ✔ | ✔ | ✅ | 2.5.12 (parcial) |
| 4.6 | Logout | Todos autenticados | ✔ | ✔ | ✔ | — | ✅ | 2.5.13 |
| 4.7 | Sessão persistente (login automático) | Usuário, ONG | — | ✔ | — | — | ✅ | Nova |
| 4.8 | Esqueci minha senha | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | Nova |
| 4.9 | Tela de Perfil | Usuário, ONG | ✔ | ✔ | ✔ (admin) | ✔ | ✅ | 2.5.16 |
| 4.10 | Editar Usuário | Usuário, Adm. Sistema | ✔ | ✔ | ✔ | ✔ | ✅ | 2.5.5 / 2.9 |
| 4.11 | Editar ONG | ONG, Adm. Sistema | ✔ | ✔ | ✔ | ✔ | ✅ | 2.5.2 |
| 4.12 | Foto de perfil | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | Nova |
| 4.13 | Excluir conta (Usuário/ONG) — anonimização LGPD | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | 2.5.3 / 2.5.6 (comportamento diferente) |
| 4.14 | Exportar meus dados (LGPD) | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | Nova |
| 4.15 | Cadastrar Serviço (usuário) | Usuário | ✔ | ✔ | — | ✔ | ✅ | 2.5.7 / 2.9 |
| 4.16 | Cadastrar Atividade (ONG) | ONG | ✔ | ✔ | — | ✔ | ✅ | 2.5.7 |
| 4.17 | Editar Serviço/Atividade | Usuário, ONG, Adm. Sistema | ✔ | ✔ | ✔ | ✔ | ✅ | 2.5.8 |
| 4.18 | Excluir Serviço/Atividade | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | 2.5.9 |
| 4.19 | Limite de serviços por plano | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | Nova |
| 4.20 | Moderação automática de serviços por IA | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | Nova |
| 4.21 | Revisão manual de serviços (fila de moderação) | Adm. Sistema | — | — | ✔ | ✔ | ✅ | Nova |
| 4.22 | Tela de Serviços (consultar serviços de usuários) | Usuário | ✔ | ✔ | — | ✔ | ✅ | 2.5.17 / 2.5.10 |
| 4.23 | Tela de ONGs (consultar atividades de ONGs) | Usuário | ✔ | ✔ | — | ✔ | ✅ | 2.5.18 / 2.5.11 |
| 4.24 | Perfil público da ONG | Usuário | ✔ | — | — | ✔ | 🟡 | 2.5.11 |
| 4.25 | Consultar Usuário | Adm. Sistema | — | — | ✔ | ✔ | 🟡 | 2.5.10 |
| 4.26 | Vagas em destaque e "Perto de você" | Usuário | ✔ | ✔ | — | ✔ | ✅ | Nova |
| 4.27 | Solicitar Serviço | Usuário | ✔ | ✔ | — | ✔ | ✅ | 2.9 (Solicitar Serviço) |
| 4.28 | Demonstrar Interesse em ONG | Usuário | ✔ | ✔ | — | ✔ | ✅ | 2.5.25 |
| 4.29 | Tela de Solicitações (aceitar/recusar) | Usuário | ✔ | ✔ | — | ✔ | ✅ | 2.5.20 |
| 4.30 | Tela de Interesse (ONG) | ONG | ✔ | ✔ | — | ✔ | ✅ | 2.5.26 |
| 4.31 | Cancelar Solicitação | Usuário | — | — | — | — | ❌ | 2.9 (Cancelar Solicitação) |
| 4.32 | Confirmar Realização do Serviço | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | 2.5.21 / 2.9 (Validar Serviço) |
| 4.33 | Confirmação de Pontos (sistema de créditos sociais) | Usuário, ONG, Adm. Sistema | ✔ | ✔ | ✔ | ✔ | ✅ | 2.5.23 |
| 4.34 | Avaliação | Usuário, ONG | ✔ | ✔ | — | ✔ | 🟡 | 2.5.24 / 2.9 |
| 4.35 | Histórico de Serviços | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | 2.5.22 |
| 4.36 | Chat | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | 2.5.19 / 2.9 |
| 4.37 | Notificações (tempo real, push e badges) | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | 2.9 (Notificação) |
| 4.38 | Contato (formulário por e-mail) | Usuário, ONG | ✔ | — | — | ✔ | 🟡 | Nova |
| 4.39 | Gerar Certificado | Usuário | ✔ | ✔ | — | ✔ | ✅ | 2.5.27 / 2.9 |
| 4.40 | Certificados emitidos (ONG) | ONG | ✔ | ✔ | — | ✔ | ✅ | Nova |
| 4.41 | Verificar autenticidade do certificado (código/QR) | Visitante | ✔ | — | — | ✔ | ✅ | Nova |
| 4.42 | Tela de Apresentação | Visitante | ✔ | ✔ | — | — | 🟠 | 2.5.14 |
| 4.43 | Tela Inicial (painel) | Usuário, ONG | ✔ | ✔ | ✔ (admin, ver 4.50) | ✔ | ✅ | 2.5.15 |
| 4.44 | Como usar a plataforma | Usuário, ONG | ✔ | — | — | — | ✅ | Nova |
| 4.45 | Quem somos | Usuário, ONG | ✔ | ✔ | — | — | ✅ | Nova |
| 4.46 | Tela de Propaganda do Premium (planos) | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | 2.5.28 |
| 4.47 | Tela de Upgrade / Contratar Premium | Usuário, ONG | ✔ | ✔ | — | ✔ | 🟠 | 2.5.29 / 2.9 |
| 4.48 | Cancelar Premium | Usuário, ONG | ✔ | ✔ | — | ✔ | ✅ | Nova |
| 4.49 | Benefícios Premium | Usuário Premium, ONG Premium | ✔ | ✔ | — | ✔ | 🟡 | 2.5.30 |
| 4.50 | Dashboard administrativo | Adm. Sistema | — | — | ✔ | ✔ | ✅ | Nova |
| 4.51 | Gerenciar Usuários | Adm. Sistema | — | — | ✔ | ✔ | ✅ | Nova |
| 4.52 | Gerenciar ONGs | Adm. Sistema | — | — | ✔ | ✔ | ✅ | Nova |
| 4.53 | Gerenciar Serviços | Adm. Sistema | — | — | ✔ | ✔ | 🟡 | Nova |
| 4.54 | Gerenciar Solicitações | Adm. Sistema | — | — | ✔ | ✔ | 🟡 | Nova |
| 4.55 | Gerenciar contas Premium | Adm. Sistema | — | — | ✔ | ✔ | ✅ | Nova |
| 4.56 | Perfil do administrador (login, senha, novo admin) | Adm. Sistema | — | — | ✔ | ✔ | ✅ | Nova |
| 4.57 | Modo escuro | Adm. Sistema | — | — | ✔ | — | ✅ | Nova |
| 4.58 | Preenchimento de endereço por CEP | Visitante, Adm. Sistema | ✔ | ✔ | ✔ | — | ✅ | Nova |

**Totais:** 58 funcionalidades — ✅ 48 · 🟡 7 · 🟠 2 · ❌ 1. **Novas** (sem correspondência em 2.5/2.9): 24.

---

## 4. Requisitos funcionais (detalhado)

### 4.1 — Cadastrar Usuário
**Status:** ✅
**Plataformas:** Web, Mobile, Desktop
**Correspondência na documentação atual:** 2.5.4 / 2.9 (Cadastrar Usuário)

**História de usuário:**
Como visitante,
quero criar uma conta de usuário comum,
para oferecer e solicitar serviços na plataforma.

**Critérios de aceite (conforme o código):**
- Web: cadastro em 3 etapas — dados básicos (nome, e-mail, telefone, tipo de conta) → CPF, senha, nascimento e foto opcional → endereço (CEP, endereço, bairro, cidade, UF).
- Mobile: 3 etapas — "Etapa 1 de 3 — Dados básicos", "Etapa 2 de 3 — Documento", "Etapa 3 de 3 — Endereço". Não há foto no cadastro do app.
- Desktop: o administrador cadastra pelo modal "Cadastro de Usuário" (tela Usuários).
- A conta nasce com `pontos = 20`, `horasVoluntarias = 0` e `email_verificado = 0`; a API envia um código de confirmação por e-mail (ver 4.3).

**Regras de negócio:**
- R1 - CPF e e-mail não podem repetir (erro `ER_DUP_ENTRY` → HTTP 409).
- R2 - A senha é gravada com hash bcrypt (custo 10).
- R3 - Web: senha com no mínimo 8 caracteres; telefone com 11 dígitos; CPF com 11 dígitos.
- R4 - Mobile: senha com no mínimo 6 caracteres; telefone com no mínimo 10 dígitos; CPF com 11 dígitos.
- R5 - Web: foto de até 5 MB no front; a API aceita até 3 MB, apenas JPG/PNG/WEBP.
- R6 - Falha no envio do e-mail não desfaz o cadastro (`emailEnviado: false`).

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Já existe uma conta com esse CPF ou e-mail." (API)
- M2 - "Não foi possível concluir o cadastro. Tente novamente." (API)
- M3 - "Enviamos um código de 6 dígitos para o seu e-mail. Confirme para ativar sua conta." (Web)
- M4 - "Sua conta foi criada, mas não conseguimos enviar o código agora. Na próxima tela, toque em \"Reenviar código\"." (Web)
- M5 - "Conta criada, mas não conseguimos enviar o código agora. Toque em \"Reenviar código\"." (Mobile)
- M6 - "Digite um CPF válido." / "A senha deve ter no mínimo 8 caracteres." / "Digite um telefone válido." (Web)
- M7 - "CPF deve ter 11 dígitos" / "Mínimo de 6 caracteres" / "Telefone incompleto" / "Email inválido" (Mobile)
- M8 - "Usuário cadastrado com sucesso!" (Desktop)

**Fluxo principal:**
1. Visitante abre "Cadastrar" e preenche os dados básicos, escolhendo "Usuário Comum".
2. Informa CPF, senha, data de nascimento (e foto, na Web).
3. Informa o CEP; o endereço é preenchido pelo ViaCEP (ver 4.58).
4. O front envia `POST /usuarios`; na Web, se houver foto, envia `POST /perfil/foto`.
5. O sistema envia o código por e-mail e leva à tela de confirmação de e-mail.

**Fluxos alternativos:**
- CPF ou e-mail já cadastrado → M1.
- Erro no envio do e-mail → M4 / M5.
- Campos inválidos → M6 / M7.

**Implementação (referência técnica):**
- Endpoints: `POST /usuarios` — cria a conta e envia código; `POST /perfil/foto` — foto (Web).
- Tabelas: `Mutuo_Usuario`, `Mutuo_ConfirmacaoEmail`.
- Arquivos: `web/cadastro.html`, `web/usuárioComum/cadastroPessoal.html`, `web/usuárioComum/cadastroLocUsuario.html` (Web); `lib/cadastro.dart`, `lib/cadastro_documento.dart`, `lib/cadastro_endereco.dart` (Mobile); `electron/src/views/usuarios.html` (Desktop); `mutuo-api/index.js` (`app.post('/usuarios')`), `mutuo-api/db.js` (`cadastrarUsuario`).

**Observações:** regras de senha diferentes entre Web (8) e Mobile (6). A página `web/cadastroConfirmacao.html` ("Cadastro realizado com sucesso!") existe, mas nenhuma página aponta para ela (o fluxo atual vai para `confirmarEmail.html`). No Desktop o cadastro não pede confirmação de senha.

---

### 4.2 — Cadastrar ONG
**Status:** ✅
**Plataformas:** Web, Mobile, Desktop
**Correspondência na documentação atual:** 2.5.1 / 2.9 (Cadastrar ONG)

**História de usuário:**
Como representante de uma ONG,
quero cadastrar minha instituição,
para divulgar atividades e receber voluntários.

**Critérios de aceite (conforme o código):**
- Web: etapa 1 (nome do responsável, e-mail, telefone, "Representante de ONG") → nome da ONG, CNPJ, senha, data de fundação, foco de atuação, descrição, foto opcional → endereço.
- Mobile: mesmas 3 etapas, com "Etapa 2 de 3 — Dados da ONG" (nome, CNPJ, data de criação, foco, descrição).
- Desktop: modal de cadastro na tela ONGs (nome, CNPJ, e-mail, responsável, telefone, CEP, cidade, bairro, endereço, senha, foco, descrição).
- A ONG nasce com `pontos = 0` e `email_verificado = 0`; recebe código por e-mail.

**Regras de negócio:**
- R1 - CNPJ e e-mail únicos (HTTP 409).
- R2 - Senha com hash bcrypt. Web exige 8 caracteres; Mobile exige 6.
- R3 - O campo `foco` é salvo em minúsculas e sem espaços nas pontas (`normalizarFoco`).
- R4 - CNPJ com 14 dígitos (Web e Mobile).

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Já existe uma conta com esse CNPJ ou e-mail."
- M2 - "Digite um CNPJ válido." / "Digite o foco de atuação." / "Digite uma descrição." (Web)
- M3 - "CNPJ deve ter 14 dígitos" / "Digite o foco de atuação" (Mobile)
- M4 - "ONG cadastrada com sucesso!" (Desktop)

**Fluxo principal:**
1. Visitante escolhe "Representante de ONG" na primeira etapa.
2. Preenche os dados da ONG e o endereço.
3. `POST /ongs`; na Web, `POST /perfil/foto/ong` se houver foto.
4. Redireciona para a confirmação de e-mail (`confirmarEmail.html?tipo=ong` / `ConfirmarEmail`).

**Fluxos alternativos:**
- CNPJ/e-mail duplicado → M1.

**Implementação (referência técnica):**
- Endpoints: `POST /ongs`, `POST /perfil/foto/ong`.
- Tabelas: `Mutuo_ONG`, `Mutuo_ConfirmacaoEmail`.
- Arquivos: `web/usuárioOng/cadastroOng1.html`, `web/usuárioOng/cadastroLocOng.html` (Web); `lib/cadastro.dart`, `lib/cadastro_documento.dart`, `lib/cadastro_endereco.dart` (Mobile); `electron/src/views/ongs.html` (Desktop); `db.js` (`cadastrarOng`).

**Observações:** a data de fundação/criação é pedida na Web e no Mobile, mas **não é gravada** (não existe no `INSERT` de `cadastrarOng`). O modal do Desktop tem o título "Cadastro de Usuário" mesmo sendo de ONG.

---

### 4.3 — Confirmação de e-mail no cadastro
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como novo usuário ou ONG,
quero confirmar meu e-mail com um código,
para ativar minha conta.

**Critérios de aceite (conforme o código):**
- Após o cadastro, a conta só entra depois de confirmar o código de 6 dígitos enviado pelo Brevo.
- O login de conta não confirmada retorna `emailNaoVerificado: true` e leva à tela de confirmação, reenviando o código.
- Contas que já existiam antes desta função foram marcadas como verificadas (`DEFAULT 1`).

**Regras de negócio:**
- R1 - Código de 6 dígitos, guardado com hash bcrypt, válido por 15 minutos.
- R2 - Máximo de 5 tentativas; ao esgotar, o código é invalidado e o reenvio fica liberado.
- R3 - Reenvio com intervalo mínimo de 60 segundos (contador "Reenviar código em m:ss").
- R4 - A resposta do reenvio é genérica (não revela se o e-mail existe).
- R5 - Redefinir a senha (4.8) também marca o e-mail como verificado.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "E-mail confirmado! Agora é só entrar."
- M2 - "Código incorreto." (+ "N tentativas restantes.")
- M3 - "Muitas tentativas. Solicite um novo código."
- M4 - "Código inválido ou expirado. Solicite um novo."
- M5 - "Se houver um cadastro pendente com esse e-mail, enviamos um novo código."
- M6 - "Confirme seu e-mail para entrar. Enviamos um código para a sua caixa de entrada." (API, no login)
- M7 - "Servidor iniciando, tente novamente em alguns segundos" (Web, quando a API está "acordando")
- M8 - "Código reenviado"

**Fluxo principal:**
1. A tela mostra o e-mail mascarado e 6 caixas para o código.
2. O usuário digita/cola o código; o front chama `POST /confirmarEmail`.
3. Com sucesso, mostra M1 e volta ao login.

**Fluxos alternativos:**
- Código errado → M2; esgotado → M3; expirado → M4.
- "Reenviar código" → `POST /reenviarConfirmacao` → M8.

**Implementação (referência técnica):**
- Endpoints: `POST /confirmarEmail`, `POST /reenviarConfirmacao`.
- Tabelas: `Mutuo_ConfirmacaoEmail`, colunas `email_verificado` em `Mutuo_Usuario`/`Mutuo_ONG`.
- Arquivos: `web/confirmarEmail.html`, `web/login.html` (Web); `lib/confirmar_email.dart`, `lib/login.dart` (Mobile); `index.js`, `db.js` (`criarCodigoRecuperacao`, `conferirCodigoRecuperacao`, `marcarEmailVerificado`).

**Observações:** limite de 30 tentativas a cada 15 min por IP (`limiteCodigo`) e 10 envios de e-mail por 15 min por IP (`limiteEnvioEmail`).

---

### 4.4 — Login (Usuário e ONG)
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.12 / 2.9 (Login)

**História de usuário:**
Como usuário ou ONG,
quero entrar com e-mail e senha,
para acessar minha área na plataforma.

**Critérios de aceite (conforme o código):**
- Web: alternância "Usuário" / "ONG" antes de entrar; chama `/loginUsuario` ou `/loginOng`.
- Mobile: um único formulário; tenta `/loginUsuario` e, se falhar, `/loginOng`.
- Sucesso: Web grava `usuarioLogado` ou `ongLogada` no `sessionStorage` e redireciona para `usuárioComum/homeMutuo.html` ou `usuárioOng/homeOngMutuo.html` após animação ("Bem-vindo de volta!" / "ONG conectada!"). Mobile salva a sessão e abre `InicialUsuario` ou `InicialOng`.
- Quem já está logado e abre `login.html` é redirecionado para a própria home.
- Botão de mostrar/ocultar senha e link "Esqueceu sua senha?".

**Regras de negócio:**
- R1 - Só contas com `ativo = 1` entram.
- R2 - Contas com `email_verificado = 0` são barradas e levadas à confirmação (4.3).
- R3 - Senhas antigas em texto puro são aceitas uma vez e migradas para bcrypt automaticamente (`verificarSenha`).
- R4 - A resposta nunca devolve a senha/hash.
- R5 - Limite de 30 tentativas por IP a cada 15 minutos (HTTP 429).
- R6 - Web exige senha com pelo menos 3 caracteres no front.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Email ou senha incorretos, ou conta inativa." (API)
- M2 - "Email e senha são obrigatórios" (API)
- M3 - "Muitas tentativas. Tente novamente em N minuto(s)." (API)
- M4 - "Digite seu e-mail." / "Digite sua senha." / "A senha deve ter no mínimo 3 caracteres." (Web)
- M5 - "Não foi possível conectar à API. Verifique se o servidor está rodando." (Web)
- M6 - "Sua conta ainda não foi confirmada. Vamos enviar um código para o seu e-mail." (Web)
- M7 - "Preencha o email e a senha." / "Confirme seu e-mail para entrar. Enviamos um código." (Mobile)
- M8 - "Login realizado com sucesso" / "Acesso da ONG realizado com sucesso" (Web)

**Fluxo principal:**
1. Usuário informa e-mail e senha (Web: escolhe o tipo).
2. API valida e devolve os dados da conta.
3. Front guarda a sessão e abre a tela inicial.

**Fluxos alternativos:**
- Credenciais erradas/conta inativa → M1.
- E-mail não confirmado → M6 → tela de confirmação.
- Excesso de tentativas → M3.

**Implementação (referência técnica):**
- Endpoints: `POST /loginUsuario`, `POST /loginOng`, `POST /reenviarConfirmacao`.
- Tabelas: `Mutuo_Usuario`, `Mutuo_ONG`.
- Arquivos: `web/login.html` (Web); `lib/login.dart`, `lib/services/auth_service.dart` (Mobile); `db.js` (`validarLoginUsuario`, `validarLoginOng`, `verificarSenha`).

**Observações:** a API **não emite token** para usuário/ONG; as demais rotas confiam no CPF/CNPJ enviado pelo cliente (ver seção 9 e `MELHORIAS.md` item 1.1).

---

### 4.5 — Login do Administrador
**Status:** ✅
**Plataformas:** Desktop
**Correspondência na documentação atual:** 2.5.12 (parcial — a documentação trata login geral)

**História de usuário:**
Como administrador do sistema,
quero entrar no painel com login e senha,
para gerenciar a plataforma.

**Critérios de aceite (conforme o código):**
- Tela "Mútuo" com campos Login e Senha.
- Sucesso: a API devolve um token HMAC (validade de 12 h); o token fica só na memória do processo principal do Electron.
- Abre a janela "Início" e fecha a de login.
- Se qualquer chamada retornar 401, o Electron volta para a tela de login.

**Regras de negócio:**
- R1 - Senha conferida com bcrypt (migração automática de texto puro).
- R2 - Limite de 30 tentativas por IP a cada 15 min.
- R3 - Sem `ADMIN_TOKEN_SECRET`, o token deixa de valer quando a API reinicia.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Preencha o Login e a Senha para continuar!"
- M2 - "Login foi realizado com sucesso. Você será redirecionado para a página inicial"
- M3 - "Login ou senha incorretos. Tente novamente."
- M4 - "Ocorreu um erro inesperado ao tentar logar."
- M5 - "Sessão de administrador inválida ou expirada." (API, 401)

**Fluxo principal:**
1. Admin informa login e senha → `POST /login`.
2. Electron guarda o token e abre `inicio.html`.

**Fluxos alternativos:**
- Campos vazios → M1. Credenciais erradas → M3. Erro de rede → M4.

**Implementação (referência técnica):**
- Endpoints: `POST /login`.
- Tabelas: `Mutuo_Adm`.
- Arquivos: `electron/src/views/index.html`, `electron/main.js`, `electron/preload.js` (Desktop); `index.js` (`gerarTokenAdm`, `autenticarAdm`), `db.js` (`validarLogin`).

**Observações:** o `ApiService` do Mobile tem o método `fazerLogin` (rota `/login`), mas nenhuma tela o usa.

---

### 4.6 — Logout
**Status:** ✅
**Plataformas:** Web, Mobile, Desktop
**Correspondência na documentação atual:** 2.5.13

**História de usuário:**
Como usuário, ONG ou administrador,
quero sair da minha conta,
para encerrar o acesso naquele dispositivo.

**Critérios de aceite (conforme o código):**
- Web: link "Sair da conta" no menu/drawer remove `usuarioLogado` e `ongLogada` do `sessionStorage` e vai para `../login.html`.
- Mobile: opção "Sair" no menu do topo chama `AuthService.logout()` (apaga a sessão salva, encerra socket e listeners) e volta ao `Login`.
- Desktop: botão "Sair" apaga o token e o login salvo e reabre a janela de login.
- Web: páginas internas verificam a sessão ao abrir e ao voltar pelo histórico (`pageshow`), redirecionando ao login se não houver sessão.

**Regras de negócio:**
- R1 - Logout não chama a API (não há sessão no servidor para usuário/ONG).

**Mensagens do sistema (texto exato encontrado no código):**
- (nenhuma mensagem específica)

**Fluxo principal:**
1. Usuário toca em "Sair da conta"/"Sair".
2. Sessão local é apagada e a tela de login é exibida.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: —
- Tabelas: —
- Arquivos: `web/navbarUsuarioResponsiva.js`, `web/navbarOngResponsiva.js` (Web); `lib/services/auth_service.dart` e menus de `inicialUser.dart`, `inicialOng.dart`, `servicos.dart`, `ongs.dart`, `chat.dart`, `notificacoes.dart` (Mobile); `electron/main.js` (`abrir-janela-login`) e botão `#sair` de cada tela (Desktop).

**Observações:** o logout do app redireciona ao Login (não à tela de apresentação).

---

### 4.7 — Sessão persistente (login automático)
**Status:** ✅
**Plataformas:** Mobile
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como usuário do app,
quero continuar logado ao reabrir o aplicativo,
para não precisar digitar a senha toda vez.

**Critérios de aceite (conforme o código):**
- Ao abrir o app, `_TelaInicial` lê `tipoLogin`, `idLogin` e `nomeLogin` do `shared_preferences`.
- Com sessão, reconecta chat/solicitações e abre direto `InicialUsuario` ou `InicialOng`; sem sessão, abre a tela de apresentação (`Carregamento`).

**Regras de negócio:**
- R1 - A sessão só é apagada pelo logout.

**Mensagens do sistema (texto exato encontrado no código):**
- (nenhuma)

**Fluxo principal:**
1. App inicia → verifica sessão → abre a home correspondente.

**Fluxos alternativos:**
- Sem sessão → tela de apresentação.

**Implementação (referência técnica):**
- Endpoints: — (na retomada, `POST /notificacoes/token` via `PushService`).
- Tabelas: —
- Arquivos: `lib/main.dart`, `lib/services/auth_service.dart`.

**Observações:** na Web a sessão fica no `sessionStorage` e acaba ao fechar a aba.

---

### 4.8 — Esqueci minha senha
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como usuário ou ONG que esqueceu a senha,
quero receber um código por e-mail e criar uma nova senha,
para recuperar o acesso.

**Critérios de aceite (conforme o código):**
- Três etapas: informar e-mail (e tipo Usuário/ONG) → digitar o código de 6 dígitos → criar nova senha (com confirmação e indicador de força "Fraca/Média/Forte" na Web).
- Código enviado pelo Brevo ("<código> é o seu código de recuperação — Mútuo").
- Ao concluir, redireciona ao login.

**Regras de negócio:**
- R1 - Código com hash bcrypt, válido por 15 minutos, 5 tentativas.
- R2 - Intervalo de 60 s entre envios; resposta genérica para não revelar se o e-mail existe.
- R3 - Nova senha com no mínimo 8 caracteres.
- R4 - `/verificarCodigo` confere sem consumir; `/redefinirSenha` confere de novo e consome o código.
- R5 - A redefinição marca o e-mail como verificado.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Se o e-mail estiver cadastrado, você receberá um código em instantes."
- M2 - "Informe o e-mail e o tipo de conta."
- M3 - "Não foi possível enviar o e-mail agora. Tente novamente em instantes."
- M4 - "A senha deve ter no mínimo 8 caracteres."
- M5 - "Senha redefinida com sucesso!" (API) / "Senha redefinida!" + "Faça login com sua nova senha" (Web) / "Senha redefinida! Faça login com sua nova senha" (Mobile)
- M6 - "As senhas não coincidem." / "Confirme a nova senha."
- M7 - "Código incorreto." / "Muitas tentativas. Solicite um novo código." / "Código inválido ou expirado. Solicite um novo."

**Fluxo principal:**
1. Usuário clica em "Esqueceu sua senha?" (o e-mail digitado no login é reaproveitado).
2. Informa e-mail e tipo → `POST /esqueciSenha` → M1.
3. Digita o código → `POST /verificarCodigo`.
4. Define nova senha → `POST /redefinirSenha` → M5 → login.

**Fluxos alternativos:**
- Falha do Brevo → M3. Código errado/expirado → M7. Senha curta → M4.
- "Trocar e-mail" volta à etapa 1 (Web).

**Implementação (referência técnica):**
- Endpoints: `POST /esqueciSenha`, `POST /verificarCodigo`, `POST /redefinirSenha`.
- Tabelas: `Mutuo_RecuperacaoSenha`, `Mutuo_Usuario`, `Mutuo_ONG`.
- Arquivos: `web/esqueciSenha.html` (Web); `lib/esqueci_senha.dart` (Mobile); `index.js`, `db.js` (`buscarContaParaRecuperacao`, `criarCodigoRecuperacao`, `conferirCodigoRecuperacao`, `redefinirSenhaComCodigo`).

**Observações:** a Web e o Mobile repetem a chamada uma vez quando a API está em cold start (resposta não-JSON).

---

### 4.9 — Tela de Perfil
**Status:** ✅
**Plataformas:** Web, Mobile (Desktop tem perfil do administrador, ver 4.56)
**Correspondência na documentação atual:** 2.5.16

**História de usuário:**
Como usuário ou ONG,
quero ver meus dados, pontos, serviços e histórico em um só lugar,
para acompanhar minha participação.

**Critérios de aceite (conforme o código):**
- **Usuário (Web `perfilMutuo.html`)**: cartão com nome, e-mail, "Trocas realizadas", "Média de avaliações", "No Mútuo" (tempo de conta); "Dados do usuário" (editar, 4.10); foto (4.12); "Saldo de pontos" com recebidos/gastos do mês; "Meus serviços" com selo de limite (4.19) e etiquetas "Ativo"/"Em análise"/"Rejeitado"; "Histórico de trocas" com abas "Serviços prestados", "Serviços utilizados", "Confirmar serviços"; "Privacidade e dados" (4.13, 4.14).
- **Usuário (Mobile `PerfilUsuario`)**: mesmos blocos; topo com "Serviços ativos" e "No Mútuo"; histórico com as mesmas três abas; "Receber meus dados por e-mail".
- **ONG (Web `perfilOngGMutuo.html`)**: total de voluntários, "Avaliação", tempo no Mútuo; dados editáveis (nome, @ gerado do nome, e-mail, telefone, cidade); saldo de pontos com movimentação do mês; "Meus serviços"; histórico com "Serviços recebidos" e "Confirmar serviços"; privacidade.
- **ONG (Mobile `PerfilOng`)**: "Atividades ativas", "Atividades realizadas", "No Mútuo"; dados; pontos; "Minhas atividades"; "Solicitações recebidas"; privacidade.

**Regras de negócio:**
- R1 - Pontos e plano são lidos da API a cada abertura (`GET /usuarios/:cpf`, `GET /ongs/:cnpj`).
- R2 - Abrir o perfil da ONG (`GET /ongs/:cnpj`) dispara o bônus mensal de pontos (ver 4.33).

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhum serviço prestado ainda." / "Nenhum serviço utilizado ainda." / "Nenhum serviço aguardando confirmação." (Web)
- M2 - "Você ainda não cadastrou nenhum serviço." / "Nada por aqui ainda." (Mobile)
- M3 - "Erro ao carregar." (Web)

**Fluxo principal:**
1. Usuário abre "Meu perfil".
2. A tela carrega dados, serviços, histórico, movimentação e plano em paralelo.

**Fluxos alternativos:**
- Falha na API → M3 nos blocos afetados.

**Implementação (referência técnica):**
- Endpoints: `GET /usuarios/:cpf`, `GET /usuarios/:cpf/estatisticas`, `GET /usuarios/:cpf/movimentacao`, `GET /servicos/usuario/:cpf`, `GET /solicitacoes/prestador/:cpf`, `GET /solicitacoes/usuario/:cpf`, `GET /solicitacoes/confirmar/:cpf`, `GET /solicitacoes-ong/usuario/:cpf`, `GET /ongs/:cnpj`, `GET /ongs/:cnpj/voluntarios-realizados`, `GET /ongs/:cnpj/movimentacao`, `GET /servicos/ong/:cnpj`, `GET /solicitacoes-ong/confirmar/:cnpj`, `GET /solicitacoes-ong/recebidos/:cnpj`, `GET /solicitacoes-ong/prestador/:cnpj`.
- Tabelas: `Mutuo_Usuario`, `Mutuo_ONG`, `Mutuo_Servico`, `Mutuo_ServicoOng`, `Mutuo_Solicitacao`, `Mutuo_SolicitacaoONG`.
- Arquivos: `web/usuárioComum/perfilMutuo.html`, `web/usuárioOng/perfilOngGMutuo.html` (Web); `lib/perfil.dart`, `lib/perfilOng.dart` (Mobile).

**Observações:** 🟠 "Média de avaliações" (usuário, Web) e "Avaliação" (ONG, Web) mostram o valor fixo **5.0**. O Mobile não mostra a movimentação mensal de pontos. Existem funções de "tags de habilidade" (`adicionarTag`/`removerTag`) no perfil Web sem campo correspondente salvo na API.

---

### 4.10 — Editar Usuário
**Status:** ✅
**Plataformas:** Web, Mobile, Desktop
**Correspondência na documentação atual:** 2.5.5 / 2.9 (Editar Dados do Usuário)

**História de usuário:**
Como usuário comum,
quero alterar meus dados pessoais,
para manter meu cadastro atualizado.

**Critérios de aceite (conforme o código):**
- Web: botão "Editar perfil" habilita nome, e-mail, telefone e cidade; "Membro desde" e plano aparecem como "Fixo".
- Mobile: edita nome completo, e-mail e telefone.
- Desktop (administrador): duplo clique na linha da tabela de usuários edita `ativo` (0/1), `pontos` e `horas` e mostra "Salvar".

**Regras de negócio:**
- R1 - Nome e e-mail obrigatórios (API).
- R2 - A cidade só é atualizada quando enviada (`atualizarDadosUsuario`).
- R3 - Rota do administrador exige token (`PUT /usuarios/:cpf`).

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nome e e-mail são obrigatórios" (API) / "Nome e e-mail são obrigatórios." (Web)
- M2 - "Perfil atualizado com sucesso!" (Web e Mobile)
- M3 - "Não foi possível salvar as alterações."
- M4 - "Salve a linha que já está em edição primeiro." (Desktop)

**Fluxo principal:**
1. Usuário clica em "Editar perfil", altera e salva.
2. `PUT /usuarios/:cpf/perfil` → M2; a sessão local é atualizada.

**Fluxos alternativos:**
- Campos obrigatórios vazios → M1.

**Implementação (referência técnica):**
- Endpoints: `PUT /usuarios/:cpf/perfil`; `PUT /usuarios/:cpf` (admin).
- Tabelas: `Mutuo_Usuario`.
- Arquivos: `web/usuárioComum/perfilMutuo.html`, `lib/perfil.dart`, `electron/src/views/usuarios.html`; `db.js` (`atualizarDadosUsuario`, `alterUsuario`).

**Observações:** não há validação de formato de e-mail nem de duplicidade com mensagem própria; um e-mail repetido cai em erro genérico do banco. Não é possível trocar a senha pelo perfil (apenas por "Esqueci minha senha").

---

### 4.11 — Editar ONG
**Status:** ✅
**Plataformas:** Web, Mobile, Desktop
**Correspondência na documentação atual:** 2.5.2

**História de usuário:**
Como ONG,
quero alterar os dados da instituição,
para manter as informações de contato corretas.

**Critérios de aceite (conforme o código):**
- Web: nome da ONG, e-mail, telefone e cidade; o @ (handle) é gerado do nome e não é editável.
- Mobile: nome da ONG, e-mail e telefone.
- Desktop (administrador): edita `nomeResponsavel`, `foco` e `ativo`.

**Regras de negócio:**
- R1 - Nome e e-mail obrigatórios.
- R2 - `atualizarDadosOng` grava sempre `cidade` com o valor recebido.
- R3 - Rota do administrador exige token (`PUT /ongs/:cnpj`); o foco é normalizado em minúsculas.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nome e e-mail são obrigatórios"
- M2 - "Perfil atualizado com sucesso!" (Web)
- M3 - "Não foi possível salvar as alterações."

**Fluxo principal:**
1. ONG edita os campos e salva → `PUT /ongs/:cnpj/perfil`.

**Fluxos alternativos:**
- Campos obrigatórios vazios → M1.

**Implementação (referência técnica):**
- Endpoints: `PUT /ongs/:cnpj/perfil`; `PUT /ongs/:cnpj` (admin).
- Tabelas: `Mutuo_ONG`.
- Arquivos: `web/usuárioOng/perfilOngGMutuo.html`, `lib/perfilOng.dart`, `electron/src/views/ongs.html`; `db.js` (`atualizarDadosOng`, `alterONG`).

**Observações:** ⚠️ o app envia só `nomeOng`, `email` e `telefone`; como a API sempre grava `cidade`, editar o perfil da ONG pelo app **apaga a cidade** (fica `NULL`). Descrição, foco e endereço da ONG não são editáveis pela própria ONG.

---

### 4.12 — Foto de perfil
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como usuário ou ONG,
quero enviar uma foto de perfil,
para ser reconhecido na plataforma.

**Critérios de aceite (conforme o código):**
- Web: clique na foto do perfil abre o seletor; a imagem é exibida na hora e enviada; aparece na navbar, drawer, cards de serviço, chat e notificações.
- Mobile: seleção pela galeria (`image_picker`); mensagem de sucesso.
- No cadastro Web a foto é opcional.

**Regras de negócio:**
- R1 - Apenas JPG, PNG ou WEBP, até 3 MB (API).
- R2 - Os bytes da imagem ficam no banco (`foto_perfil_dados`), porque o disco do Render não é persistente; o arquivo em `uploads/` é usado como reserva.
- R3 - Nome do arquivo: `<cpf ou cnpj>-<timestamp>.<ext>`.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Apenas imagens JPG, PNG ou WEBP são aceitas."
- M2 - "A imagem deve ter no máximo 3 MB."
- M3 - "CPF não informado" / "CNPJ não informado" / "Nenhum arquivo enviado"
- M4 - "Foto de perfil atualizada!" (Mobile)
- M5 - "A foto deve ter no máximo 5 MB." (Web, cadastro)

**Fluxo principal:**
1. Usuário escolhe a imagem → `POST /perfil/foto` (ou `/perfil/foto/ong`).
2. A API grava nome e bytes e devolve o caminho `/uploads/fotos/<nome>`.

**Fluxos alternativos:**
- Tipo/tamanho inválido → M1/M2.

**Implementação (referência técnica):**
- Endpoints: `POST /perfil/foto`, `GET /perfil/foto/:cpf`, `POST /perfil/foto/ong`, `GET /perfil/foto/ong/:cnpj`, `GET /uploads/fotos/:nome`.
- Tabelas: `Mutuo_Usuario` / `Mutuo_ONG` (`foto_perfil`, `foto_perfil_dados`, `foto_perfil_tipo`).
- Arquivos: `web/funcoes.js` (`enviarFoto`, `carregarFoto`), `web/usuárioOng/perfilOngGMutuo.html` (Web); `lib/perfil.dart`, `lib/perfilOng.dart`, `lib/widgets/avatar_perfil.dart` (Mobile).

**Observações:** `web/funcoes.js` tem `enviarFotoOng` apontando para `/perfil/fotoOng` (rota inexistente), mas a função não é usada; o perfil da ONG usa a rota correta.

---

### 4.13 — Excluir conta (Usuário/ONG) — anonimização LGPD
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.3 (Excluir ONG) / 2.5.6 (Excluir Usuário) — comportamento diferente (ver 8.3)

**História de usuário:**
Como usuário ou ONG,
quero excluir minha conta,
para que meus dados pessoais sejam removidos.

**Critérios de aceite (conforme o código):**
- Seção "Privacidade e dados" do perfil → "Excluir minha conta".
- Aviso com consequências → confirmação com senha e digitação de "EXCLUIR".
- Após excluir, a sessão é encerrada e o usuário vai para o login.

**Regras de negócio:**
- R1 - A conta é identificada por e-mail + senha + tipo (não por CPF/CNPJ do cliente).
- R2 - **Excluir = anonimizar**: usuário vira "Usuário removido", e-mail trocado por `removido+...@mutuo.invalid`, senha aleatória, telefone/endereço/CEP/nascimento/foto apagados, `ativo = 0`, `excluido_em = NOW()`, serviços desativados.
- R3 - ONG: responsável vira "Responsável removido", contatos/descrição/foto apagados; **mantém** `nomeOng` e `cnpj`; atividades desativadas.
- R4 - Tokens de push da conta são apagados.
- R5 - O CPF/CNPJ continua na base; não é possível recadastrar o mesmo documento.
- R6 - Operação em transação.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Digite EXCLUIR para confirmar."
- M2 - "Senha incorreta."
- M3 - "Informe e-mail, senha e tipo de conta."
- M4 - "Sua conta foi excluída."
- M5 - "Não foi possível excluir a conta agora. Tente novamente."
- M6 - (Web, aviso) "Seus dados pessoais serão apagados." / "Seus serviços sairão do ar." / "Certificados já emitidos continuam válidos, mas sem o seu nome." / "Não dá para desfazer nem criar outra conta com o mesmo CPF."

**Fluxo principal:**
1. Usuário clica em "Excluir minha conta" e confirma o aviso.
2. Digita senha e "EXCLUIR" → `POST /minhaConta/excluir`.
3. API anonimiza → M4 → login.

**Fluxos alternativos:**
- Senha errada → M2. Confirmação errada → M1.

**Implementação (referência técnica):**
- Endpoints: `POST /minhaConta/excluir`.
- Tabelas: `Mutuo_Usuario`, `Mutuo_ONG`, `Mutuo_Servico`, `Mutuo_ServicoOng`, `Mutuo_DispositivoToken`.
- Arquivos: `web/usuárioComum/perfilMutuo.html`, `web/usuárioOng/perfilOngGMutuo.html` (Web); `lib/perfil.dart`, `lib/perfilOng.dart` (Mobile); `index.js` (`identificarContaPorSenha`), `db.js` (`anonimizarConta`).

**Observações:** o administrador também pode **inativar** usuários e ONGs (`ativo = 0`) pelo Desktop (4.51/4.52). Não há exclusão física de registros em nenhuma plataforma.

---

### 4.14 — Exportar meus dados (LGPD)
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como usuário ou ONG,
quero baixar uma cópia dos meus dados,
para exercer meu direito de acesso (LGPD).

**Critérios de aceite (conforme o código):**
- Web: "Baixar meus dados" → confirma senha → baixa `meus-dados-mutuo.json`.
- Mobile: "Receber meus dados por e-mail" → confirma senha → a API envia o JSON como anexo para o e-mail da conta.
- Conteúdo (usuário): perfil, serviços oferecidos, solicitações feitas e recebidas, participações em ONGs, certificados, conversas. (ONG): perfil, serviços, solicitações recebidas, certificados emitidos, conversas.

**Regras de negócio:**
- R1 - Identificação por e-mail + senha + tipo.
- R2 - O e-mail de destino é sempre o do banco, nunca o enviado no corpo.
- R3 - Se uma parte falhar, ela vai como `null` e o restante é exportado.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Enviamos seus dados para o e-mail da sua conta."
- M2 - "O arquivo meus-dados-mutuo.json foi salvo no seu computador." (Web)
- M3 - "Senha incorreta."
- M4 - "Não foi possível enviar o e-mail agora. Tente novamente em instantes."

**Fluxo principal:**
1. Usuário confirma a senha → `POST /minhaConta/dados` (com `enviarPorEmail` no app).
2. Web baixa o arquivo; app recebe M1.

**Fluxos alternativos:**
- Senha errada → M3. Falha do Brevo → M4.

**Implementação (referência técnica):**
- Endpoints: `POST /minhaConta/dados`.
- Tabelas: todas as relacionadas à conta (leitura).
- Arquivos: `web/usuárioComum/perfilMutuo.html`, `web/usuárioOng/perfilOngGMutuo.html`; `lib/perfil.dart`, `lib/perfilOng.dart`; `index.js` (`montarExportacao`).

**Observações:** o e-mail de exportação diz: "Olá! Em anexo estão os dados da sua conta no Mútuo, em formato JSON, como você pediu."

---

### 4.15 — Cadastrar Serviço (usuário)
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.7 / 2.9 (Cadastrar Serviço)

**História de usuário:**
Como usuário comum,
quero cadastrar um serviço que sei fazer,
para que outras pessoas possam solicitá-lo.

**Critérios de aceite (conforme o código):**
- Campos: nome do serviço, descrição (até 150 caracteres na Web), foco (lista), duração, pontos (10 a 50) e imagem opcional.
- Foco na Web: educação, saúde, animais, idosos, esporte, manutenção, tecnologia, limpeza, outro. No Mobile: lista própria (culinária, jardinagem, música, tecnologia, educação, animais, ambiental…).
- Antes de salvar, o serviço passa pela moderação por IA (4.20) com tela "Verificando seu serviço".
- Resultado APROVADO → "Serviço cadastrado com sucesso!"; REVISAO → fica oculto até o admin aprovar; BLOQUEADO → não é salvo.

**Regras de negócio:**
- R1 - Todos os campos obrigatórios, exceto imagem.
- R2 - Pontos entre 10 e 50.
- R3 - Limite de serviços ativos: 3 (gratuito) ou 8 (Premium) (4.19).
- R4 - Imagem JPG/PNG/WEBP até 3 MB; bytes gravados no banco.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Preencha todos os campos obrigatórios."
- M2 - "Os pontos devem estar entre 10 e 50."
- M3 - "Serviço cadastrado com sucesso!"
- M4 - "Serviço enviado para análise. Ele ficará disponível após a conclusão da revisão."
- M5 - "Serviço não publicado" + "Não foi possível publicar este serviço. O conteúdo informado pode violar as diretrizes do Mútuo. Revise as informações e tente novamente."
- M6 - "Você atingiu o limite de 3 serviços do plano gratuito. Assine o Premium para cadastrar até 8 serviços."
- M7 - "O servidor está iniciando. Tente novamente em alguns segundos." (Web)

**Fluxo principal:**
1. Usuário abre "Adicionar" em "Meus serviços".
2. Preenche e confirma → `POST /servicos` (multipart).
3. API checa limite, modera, grava → M3 ou M4 → volta ao perfil.

**Fluxos alternativos:**
- Bloqueado pela IA → M5. Limite atingido → M6 (HTTP 403).

**Implementação (referência técnica):**
- Endpoints: `POST /servicos`.
- Tabelas: `Mutuo_Servico`.
- Arquivos: `web/usuárioComum/adicionarServicoMutuo.html`, `web/moderacao.js` (Web); `lib/perfil.dart` (modal), `lib/widgets/moderacao_dialogs.dart` (Mobile); `index.js`, `db.js` (`cadastrarServico`), `mutuo-api/moderation/`.

**Observações:** a duração é texto livre ("Ex: 2 horas"), mas é gravada em `qtdHoras` e usada em somas de horas.

---

### 4.16 — Cadastrar Atividade (ONG)
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.7

**História de usuário:**
Como ONG,
quero cadastrar uma atividade de voluntariado,
para receber voluntários interessados.

**Critérios de aceite (conforme o código):**
- Mesmos campos do serviço de usuário; foco na Web: educação, saúde, animais, idosos, meio ambiente, assistência social, diversidade, outro.
- Mobile: modal "Cadastro de atividade" (`modal_atividade_ong.dart`).
- Passa pela moderação por IA.

**Regras de negócio:**
- R1 - Pontos entre 10 e 50.
- R2 - Limite: 5 atividades ativas (gratuito) ou 10 (Premium).

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Atividade cadastrada com sucesso!" (Mobile)
- M2 - "Você atingiu o limite de 5 serviços do plano gratuito. Assine o Premium para cadastrar até 10 serviços." (API)
- M3 - "Seu plano gratuito permite até 5 atividades ativas. Faça upgrade para o plano Premium para cadastrar mais atividades." (Mobile)
- M4 - "Sessão expirada. Faça login novamente." (Web)
- M5 - mesmas mensagens de moderação de 4.15.

**Fluxo principal:**
1. ONG clica em "Adicionar" / "Criar atividade" → preenche → `POST /servicos/ong`.

**Fluxos alternativos:**
- Limite atingido → M2/M3. Bloqueio pela IA → popup "Serviço não publicado".

**Implementação (referência técnica):**
- Endpoints: `POST /servicos/ong`.
- Tabelas: `Mutuo_ServicoOng`.
- Arquivos: `web/usuárioOng/adicionarServicoOng.html` (Web); `lib/widgets/modal_atividade_ong.dart`, `lib/servicosOng.dart`, `lib/inicialOng.dart` (Mobile); `db.js` (`cadastrarServicoOng`).

**Observações:** a lista de focos da ONG na Web tem o valor "assitência social" (com erro de digitação), gravado assim no banco.

---

### 4.17 — Editar Serviço/Atividade
**Status:** ✅
**Plataformas:** Web, Mobile, Desktop
**Correspondência na documentação atual:** 2.5.8

**História de usuário:**
Como dono de um serviço (usuário ou ONG),
quero alterar seus dados,
para mantê-lo atualizado.

**Critérios de aceite (conforme o código):**
- Web: páginas "Editar serviço" (usuário e ONG) carregam os dados atuais; Mobile usa o mesmo modal do cadastro.
- Se nome, descrição, foco ou imagem mudarem, o serviço volta para a moderação por IA; se só pontos/duração mudarem, não.
- Desktop: duplo clique edita foco, horas, ativo e nota de serviços de usuários.

**Regras de negócio:**
- R1 - Pontos entre 10 e 50.
- R2 - Bloqueio na reavaliação → nada é gravado.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Serviço atualizado com sucesso!" / "Atividade atualizada com sucesso!"
- M2 - "Serviço enviado para análise. Ele ficará disponível após a conclusão da revisão."
- M3 - "Serviço não encontrado." (API)

**Fluxo principal:**
1. Usuário clica em "Editar" no card → altera → salva (`PUT /servicos/:id` ou `PUT /servicos/ong/:id`).

**Fluxos alternativos:**
- Bloqueado → popup de moderação.

**Implementação (referência técnica):**
- Endpoints: `GET /servicos/:id`, `PUT /servicos/:id`, `GET /servicos/ong/detalhe/:id`, `PUT /servicos/ong/:id`, `PUT /adm/servicos/:cod` (admin).
- Tabelas: `Mutuo_Servico`, `Mutuo_ServicoOng`.
- Arquivos: `web/usuárioComum/editarServicoMutuo.html`, `web/usuárioOng/editarServicoOng.html`; `lib/perfil.dart`, `lib/widgets/modal_atividade_ong.dart`; `electron/src/views/servicos.html`; `db.js` (`atualizarServico`, `atualizarServicoOng`, `alterServico`).

**Observações:** na página de edição do usuário (Web), a opção "Saúde" tem o valor `saúdes`. A rota do admin grava a nota numa coluna `avaliacao` de `Mutuo_Servico`, que não aparece em nenhuma outra consulta (as demais usam `nota`) — ver 4.53.

---

### 4.18 — Excluir Serviço/Atividade
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.9

**História de usuário:**
Como dono de um serviço,
quero excluí-lo,
para que ele não apareça mais.

**Critérios de aceite (conforme o código):**
- Botão "Excluir" no card (perfil, "Minhas atividades", tela de edição da ONG) com confirmação.
- Exclusão lógica: `ativo = 0` (o registro continua no banco).

**Regras de negócio:**
- R1 - Serviços com `ativo = 0` deixam de aparecer nas listagens e não contam no limite do plano.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Tem certeza que deseja excluir este serviço?" / "Tem certeza que deseja excluir esta atividade?"
- M2 - "Atividade excluída com sucesso!"
- M3 - "Não foi possível excluir o serviço."
- M4 - "Campo \"ativo\" não informado." / "Informe o campo \"ativo\"." (API)

**Fluxo principal:**
1. Usuário clica em "Excluir" e confirma → `PATCH /servicos/:id/status` ou `PATCH /servicos/ong/:id/status` com `{ ativo: 0 }`.

**Fluxos alternativos:**
- Erro → M3.

**Implementação (referência técnica):**
- Endpoints: `PATCH /servicos/:id/status`, `PATCH /servicos/ong/:id/status`.
- Tabelas: `Mutuo_Servico`, `Mutuo_ServicoOng`.
- Arquivos: `web/usuárioComum/perfilMutuo.html`, `web/usuárioOng/perfilOngGMutuo.html`, `web/usuárioOng/editarServicoOng.html`; `lib/perfil.dart`, `lib/perfilOng.dart`, `lib/servicosOng.dart`.

**Observações:** solicitações já existentes do serviço não são canceladas.

---

### 4.19 — Limite de serviços por plano
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** Nova (relacionada a 2.5.30)

**História de usuário:**
Como usuário ou ONG,
quero saber quantos serviços ainda posso cadastrar,
para decidir se preciso do plano Premium.

**Critérios de aceite (conforme o código):**
- Usuário: 3 ativos (gratuito) / 8 (Premium). ONG: 5 / 10.
- Selo "N/limite serviços usados"; ao atingir, o botão "Adicionar" vira "Ver planos".

**Regras de negócio:**
- R1 - A API conta só serviços com `ativo = 1` e recusa com HTTP 403 ao atingir o limite.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "N/3 serviços usados — vire Premium para cadastrar até 8" (Web, texto montado)
- M2 - "Limite de 3 serviços do plano gratuito consumido. Assine o Premium pra cadastrar até 8." (Mobile)
- M3 - "Limite de 5 atividades do plano gratuito consumido. Faça upgrade pra cadastrar mais." (Mobile)
- M4 - "Você atingiu o limite de N serviços do plano Premium." (API)

**Fluxo principal:**
1. Ao carregar o perfil/home, o front compara a quantidade com o limite do plano.

**Fluxos alternativos:**
- Tentativa acima do limite → HTTP 403 com a mensagem da API.

**Implementação (referência técnica):**
- Endpoints: `POST /servicos`, `POST /servicos/ong` (checagem), `GET /usuarios/:cpf`, `GET /ongs/:cnpj` (plano).
- Tabelas: `Mutuo_Servico`, `Mutuo_ServicoOng`, `Mutuo_Usuario.premium`, `Mutuo_ONG.premium`.
- Arquivos: `web/usuárioComum/perfilMutuo.html`, `web/usuárioOng/homeOngMutuo.html`, `web/usuárioOng/perfilOngGMutuo.html`; `lib/perfil.dart`, `lib/inicialOng.dart`, `lib/servicosOng.dart`, `lib/perfilOng.dart`; `db.js` (`contarServicosAtivosUsuario`, `contarServicosAtivosOng`).

**Observações:** o app da ONG só calcula o limite gratuito (`>= 5`) e mostra "Plano gratuito: N/5 atividades"; a ONG Premium passa a não ver limite no app, mas a API limita a 10.

---

### 4.20 — Moderação automática de serviços por IA
**Status:** ✅
**Plataformas:** Web, Mobile (API)
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como plataforma,
quero analisar automaticamente cada serviço antes de publicar,
para impedir conteúdo ilegal, perigoso ou fora do propósito do Mútuo.

**Critérios de aceite (conforme o código):**
- Ao cadastrar ou editar (com mudança de conteúdo), a API chama `avaliarServico`.
- **Camada 1** (regras locais, sem IA): bloqueia nome/descrição vazios, descrição com menos de 8 caracteres, repetição de um caractere 10+ vezes ou texto com mais de 80% em maiúsculas (categoria SPAM).
- **Camada 2** (Gemini, texto + imagem): segurança geral — VIOLENCIA, SEXUAL, EXPLORACAO, DISCRIMINACAO, PERIGOSO, ILICITO.
- **Camada 3** (Gemini, só para aprovados na 2): política do Mútuo — FRAUDE, DROGAS, ARMAS, PIRATARIA, SPAM, FORA_DO_ESCOPO, OUTROS.
- Resultado: APROVADO (publica), REVISAO (grava oculto para o admin), BLOQUEADO (não grava e apaga a imagem enviada).
- Telas: overlay "Verificando seu serviço" com etapas e popup "Serviço não publicado".

**Regras de negócio:**
- R1 - Se a IA estiver indisponível (sem chave, timeout de 20 s, erro), o serviço vai para REVISAO — nunca é publicado sem checagem.
- R2 - Modelo principal + modelo reserva; nova tentativa após 1,5 s em HTTP 503.
- R3 - Só serviços `APROVADO` aparecem nas listagens públicas.
- R4 - A IA nunca bane o usuário; a decisão afeta só o serviço.
- R5 - Registro em log com status, categoria e confiança (sem o texto do serviço).

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Este serviço não atende às diretrizes de publicação do Mútuo."
- M2 - "Seu serviço foi enviado para análise antes da publicação."
- M3 - "Verificando seu serviço" / "Nossa IA está analisando o conteúdo para garantir que ele segue as diretrizes do Mútuo. Isso pode levar alguns segundos."
- M4 - "Lendo as informações do serviço..." / "Verificando as diretrizes do Mútuo..." / "Quase pronto..."
- M5 - "Serviço não publicado" / "Revisar serviço"
- M6 - Etiquetas nos cards: "Em análise" / "Rejeitado".

**Fluxo principal:**
1. Usuário envia o serviço → overlay de verificação.
2. API aplica as camadas 1, 2 e 3 → grava com `moderacao_status`.
3. Front mostra sucesso, "enviado para análise" ou o popup de bloqueio.

**Fluxos alternativos:**
- REVISAO → aparece na tela "Revisão" do Desktop (4.21).

**Implementação (referência técnica):**
- Endpoints: `POST /servicos`, `PUT /servicos/:id`, `POST /servicos/ong`, `PUT /servicos/ong/:id`.
- Tabelas: `Mutuo_Servico` e `Mutuo_ServicoOng` (colunas `moderacao_status`, `moderacao_categoria`, `moderacao_motivo`, `moderacao_confianca`, `moderacao_data`, `moderacao_revisado_por`, `moderacao_data_revisao`).
- Arquivos: `mutuo-api/moderation/moderationService.js`, `rules.js`, `policy.js`, `testar-moderacao.js` (13 casos de teste manuais); `web/moderacao.js`; `lib/widgets/moderacao_dialogs.dart`.

**Observações:** depende da variável `GEMINI_API_KEY`.

---

### 4.21 — Revisão manual de serviços (fila de moderação)
**Status:** ✅
**Plataformas:** Desktop
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como administrador do sistema,
quero revisar os serviços que a IA marcou como duvidosos,
para aprovar ou rejeitar a publicação.

**Critérios de aceite (conforme o código):**
- Tela "Revisão de Serviços" lista serviços de usuários e de ONGs com `moderacao_status = 'REVISAO'`.
- Cada card mostra imagem, nome, tipo (Usuário/ONG), criador, foco, horas, descrição, categoria da IA, barra de confiança (%), motivo e data da análise.
- Botões "Aprovar" e "Rejeitar" com confirmação; contador "N pendente(s)"; botão de recarregar; busca por nome.

**Regras de negócio:**
- R1 - Aprovar → `APROVADO`; Rejeitar → `BLOQUEADO`; grava o login do admin e a data da revisão.
- R2 - Todo texto vindo da API é escapado antes de ir para o HTML.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Aprovar serviço?" / "O serviço será publicado e ficará visível para todos."
- M2 - "Rejeitar serviço?" / "O serviço não será publicado."
- M3 - "Serviço aprovado!" / "Serviço rejeitado."
- M4 - "Nenhum serviço pendente de revisão. 🎉"
- M5 - "Tipo inválido." / "Ação inválida." (API)

**Fluxo principal:**
1. Admin abre "Revisão" → `GET /moderacao/servicos`.
2. Clica em Aprovar/Rejeitar → confirma → `PUT /moderacao/servicos/:tipo/:id`.

**Fluxos alternativos:**
- Erro → "Não foi possível concluir."

**Implementação (referência técnica):**
- Endpoints: `GET /moderacao/servicos`, `PUT /moderacao/servicos/:tipo/:id` (token de admin).
- Tabelas: `Mutuo_Servico`, `Mutuo_ServicoOng`.
- Arquivos: `electron/src/views/revisao.html`, `electron/main.js`; `db.js` (`getServicosParaRevisao`, `atualizarModeracaoServico`).

**Observações:** —

---

### 4.22 — Tela de Serviços (consultar serviços de usuários)
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.17 / 2.5.10

**História de usuário:**
Como usuário comum,
quero buscar serviços oferecidos por outros usuários,
para encontrar o que preciso.

**Critérios de aceite (conforme o código):**
- Lista todos os serviços ativos e aprovados de usuários ativos, exceto os do próprio usuário.
- Card: imagem, foco, pontos, nome, descrição, foto/nome do autor, cidade/UF, horas; botões "Tirar dúvidas" (abre chat) e "Solicitar".
- Web: busca por texto (nome, descrição, autor), categorias dinâmicas (focos existentes), filtros de localização, duração (até 2h, 3–5h, mais de 5h), pontos (até 50, 51–100, mais de 100) e ordenação (mais recentes, nome A–Z, menos/mais pontos, menor duração); contador de resultados.
- Mobile: busca por texto (título/autor), chips de categoria; card "Saiba mais" abre o detalhe.

**Regras de negócio:**
- R1 - Só `moderacao_status = 'APROVADO'`, `ativo = 1` (serviço e dono).
- R2 - Cidades normalizadas para "Primeira Letra Maiúscula" no filtro (Web).
- R3 - Mobile impede solicitar o próprio serviço.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhum serviço encontrado." (Web) / "Nenhum serviço encontrado" (Mobile)
- M2 - "Não foi possível carregar os serviços agora. Tente novamente mais tarde."
- M3 - "Você não pode solicitar seu próprio serviço." (Mobile)

**Fluxo principal:**
1. Usuário abre "Serviços" → `GET /servicos-usuario`.
2. Aplica busca/filtros e escolhe um serviço.

**Fluxos alternativos:**
- Lista vazia → M1.

**Implementação (referência técnica):**
- Endpoints: `GET /servicos-usuario`.
- Tabelas: `Mutuo_Servico`, `Mutuo_Usuario`.
- Arquivos: `web/usuárioComum/serviçosMutuo.html` (Web); `lib/servicos.dart` (Mobile).

**Observações:** 🟡 no Mobile o chip "Filtros" não tem ação (`onTap: () {}`). Os filtros de pontos "51 a 100" e "mais de 100" nunca retornam resultado porque a API limita os pontos a 50.

---

### 4.23 — Tela de ONGs (consultar atividades de ONGs)
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.18 / 2.5.11

**História de usuário:**
Como usuário comum,
quero ver as atividades de voluntariado das ONGs,
para escolher onde ajudar.

**Critérios de aceite (conforme o código):**
- Lista atividades ativas e aprovadas de ONGs ativas.
- Web: mesmos filtros/ordenação da tela de Serviços; o nome da ONG é link para o perfil público (4.24); botões "Tirar dúvidas" e "Solicitar".
- Mobile: busca ("Buscar atividades de ONGs..."), chips de categoria; detalhe com "Tirar dúvidas" e "Quero participar".

**Regras de negócio:**
- R1 - Só `moderacao_status = 'APROVADO'`.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhum serviço encontrado." (Web) / "Nenhuma atividade encontrada" (Mobile)
- M2 - "Não foi possível carregar os serviços agora. Tente novamente mais tarde."

**Fluxo principal:**
1. Usuário abre "ONGs" → `GET /servicos-ong` → filtra e escolhe.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /servicos-ong`.
- Tabelas: `Mutuo_ServicoOng`, `Mutuo_ONG`.
- Arquivos: `web/usuárioComum/OngsMutuo.html`; `lib/ongs.dart`.

**Observações:** a tela lista **atividades**, não um catálogo de ONGs. No Mobile o chip "Filtros" não tem ação.

---

### 4.24 — Perfil público da ONG
**Status:** 🟡
**Plataformas:** Web
**Correspondência na documentação atual:** 2.5.11 (Consultar ONG)

**História de usuário:**
Como usuário comum,
quero ver o perfil de uma ONG,
para conhecer a instituição e suas atividades.

**Critérios de aceite (conforme o código):**
- Página `perfilOngMutuo.html?cnpj=...`: capa e avatar (foto da ONG), nome, cidade/UF, foco, endereço, e-mail, telefone.
- Abas "Sobre" (descrição) e "Serviços" (atividades ativas e aprovadas); "Saiba mais" abre modal da atividade.

**Regras de negócio:**
- R1 - Só atividades `ativo = 1` e `APROVADO`.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "ONG não especificada."
- M2 - "Não foi possível carregar esta ONG."
- M3 - "Esta ONG ainda não adicionou uma descrição."
- M4 - "Esta ONG ainda não cadastrou serviços."

**Fluxo principal:**
1. Usuário clica no nome da ONG na tela de ONGs → `GET /ongs/:cnpj`.

**Fluxos alternativos:**
- CNPJ ausente/inválido → M1/M2.

**Implementação (referência técnica):**
- Endpoints: `GET /ongs/:cnpj`.
- Tabelas: `Mutuo_ONG`, `Mutuo_ServicoOng`.
- Arquivos: `web/usuárioComum/perfilOngMutuo.html`.

**Observações:** parcial porque, no modal da atividade, o botão "Inscrever-me como voluntário" **não tem ação** e "Converse conosco" abre o chat sem selecionar a ONG. Não existe tela equivalente no Mobile.

---

### 4.25 — Consultar Usuário
**Status:** 🟡
**Plataformas:** Desktop
**Correspondência na documentação atual:** 2.5.10 (Consultar Usuário ou Serviço)

**História de usuário:**
Como administrador do sistema,
quero localizar um usuário,
para consultar seus dados.

**Critérios de aceite (conforme o código):**
- Tela "Gerenciamento de Usuários" com busca por nome ou CPF (filtro local, atraso de 300 ms).

**Regras de negócio:**
- R1 - A listagem completa exige token de administrador.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhum usuário encontrado"

**Fluxo principal:**
1. Admin digita nome/CPF; a tabela é filtrada.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /usuarios` (admin).
- Tabelas: `Mutuo_Usuario`.
- Arquivos: `electron/src/views/usuarios.html`.

**Observações:** parcial porque usuários comuns e ONGs **não** têm busca de usuários nem tela de perfil público de outro usuário; a busca existente é de serviços (4.22).

---

### 4.26 — Vagas em destaque e "Perto de você"
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** Nova (é um benefício Premium — 2.5.30)

**História de usuário:**
Como usuário comum,
quero ver serviços em destaque e próximos de mim na tela inicial,
para encontrar oportunidades rapidamente.

**Critérios de aceite (conforme o código):**
- "Vagas em destaque": serviços de **usuários Premium** e atividades de **ONGs Premium** (exceto os do próprio usuário), em carrossel.
- "Perto de você" (só Web): o mesmo, filtrado pela cidade cadastrada do usuário.
- Botões "Tirar dúvidas" (chat) e "Solicitar" (usa `/solicitacoes` ou `/solicitacoes-ong` conforme o tipo).

**Regras de negócio:**
- R1 - Só itens aprovados e ativos de contas `premium = 1`.
- R2 - "Perto de você" compara `cidade` exatamente igual à do usuário.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhuma vaga em destaque no momento." (Web) / "Nenhuma vaga em destaque no momento" (Mobile)
- M2 - "Não possui serviços premium nessa região."
- M3 - "Solicitação enviada! Aguarde a aprovação do prestador do serviço."
- M4 - "Não foi possível carregar as vagas em destaque."

**Fluxo principal:**
1. Tela inicial carrega `GET /servicos-destaque?cpf=` e `GET /servicos-perto/:cidade?cpf=`.

**Fluxos alternativos:**
- Sem cidade cadastrada → M2.

**Implementação (referência técnica):**
- Endpoints: `GET /servicos-destaque`, `GET /servicos-perto/:cidade`.
- Tabelas: `Mutuo_Servico`, `Mutuo_ServicoOng`, `Mutuo_Usuario`, `Mutuo_ONG`.
- Arquivos: `web/usuárioComum/homeMutuo.html`; `lib/inicialUser.dart`.

**Observações:** 🟠 no Mobile, o botão "Participar" do detalhe da vaga em destaque **não chama a API** — só mostra "Inscrição realizada!". Não é geolocalização: usa a cidade do cadastro.

---

### 4.27 — Solicitar Serviço
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.9 (Solicitar Serviço)

**História de usuário:**
Como usuário comum,
quero solicitar o serviço de outro usuário,
para receber a ajuda de que preciso usando meus pontos.

**Critérios de aceite (conforme o código):**
- Botão "Solicitar" (Web) / "Solicitar" no detalhe (Mobile).
- Cria a solicitação com `statusSolicitacao = 'Pendente'` e `statusExecucao = 'Não iniciado'`.
- O prestador recebe badge em tempo real (Socket.IO `solicitacao:nova`) e push ("<nome> — Quer solicitar seu serviço \"<serviço>\"").

**Regras de negócio:**
- R1 - `codServico` e `codUsuario` obrigatórios.
- R2 - Não há verificação de saldo de pontos ao solicitar nem de solicitação duplicada.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Solicitação enviada! Aguarde a aprovação do prestador do serviço." (Web)
- M2 - "Solicitação enviada!" (Mobile)
- M3 - "Não foi possível enviar a solicitação. Tente novamente." (Web) / "Não foi possível enviar a solicitação." (Mobile)
- M4 - "Você precisa estar logado para se inscrever em um serviço." (Web)
- M5 - "codServico e codUsuario são obrigatórios." (API)

**Fluxo principal:**
1. Usuário clica em "Solicitar" → `POST /solicitacoes`.
2. Prestador é notificado.

**Fluxos alternativos:**
- Sem sessão → M4. Erro → M3.

**Implementação (referência técnica):**
- Endpoints: `POST /solicitacoes`.
- Tabelas: `Mutuo_Solicitacao`.
- Arquivos: `web/usuárioComum/serviçosMutuo.html`, `web/usuárioComum/homeMutuo.html`, `web/funcoes.js` (`inscreverServico`); `lib/servicos.dart`.

**Observações:** —

---

### 4.28 — Demonstrar Interesse em ONG
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.25

**História de usuário:**
Como usuário comum,
quero me inscrever em uma atividade de ONG,
para participar como voluntário.

**Critérios de aceite (conforme o código):**
- Web: "Solicitar" na tela de ONGs (e nas vagas em destaque de ONGs); Mobile: "Quero participar".
- Cria registro em `Mutuo_SolicitacaoONG` como "Pendente"; a ONG recebe badge e push ("Quer participar de \"<atividade>\"").

**Regras de negócio:**
- R1 - `codServico` e `codUsuario` obrigatórios.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Inscrição realizada com sucesso!" (Web)
- M2 - "Solicitação enviada!" (Mobile)
- M3 - "Sessão expirada. Faça login novamente." (Web)

**Fluxo principal:**
1. Usuário escolhe a atividade → `POST /solicitacoes-ong`.

**Fluxos alternativos:**
- Erro → "Não foi possível se inscrever no serviço." (Web).

**Implementação (referência técnica):**
- Endpoints: `POST /solicitacoes-ong`.
- Tabelas: `Mutuo_SolicitacaoONG`.
- Arquivos: `web/usuárioComum/OngsMutuo.html`, `web/usuárioComum/homeMutuo.html`; `lib/ongs.dart`.

**Observações:** o botão do perfil público da ONG ("Inscrever-me como voluntário") não funciona (ver 4.24).

---

### 4.29 — Tela de Solicitações (aceitar/recusar)
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.20

**História de usuário:**
Como usuário que oferece serviços,
quero ver e responder as solicitações recebidas,
para combinar a troca.

**Critérios de aceite (conforme o código):**
- Web (`notificacoesMutuo.html`, título "Notificações"): filtros "Todas", "Recebidas", "Meus pedidos", "Mensagens"; contador "N nova(s)"; cards com status (Pendente/Aceita/Recusada), tempo relativo e botões "Aceitar", "Recusar", "Mensagem".
- "Meus pedidos" mostra as solicitações feitas pelo usuário (a usuários e a ONGs) com o status.
- Mobile (`Notificacoes`, título "Solicitações"): lista de solicitações recebidas com "Aceitar", "Recusar" e "Enviar mensagem"; abrir marca como lida.

**Regras de negócio:**
- R1 - Aceitar → `statusSolicitacao = 'Aceita'`; Recusar → `'Recusada'` (Web grava `statusExecucao = 'Cancelado'`).
- R2 - Responder marca a solicitação como lida e avisa o solicitante por socket e push ("Sua solicitação foi aceita!" / "Sua solicitação foi recusada.").

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhuma solicitação recebida." / "Nenhuma notificação." (Web)
- M2 - "Nenhuma solicitação ainda" + "Solicitações de outras contas pelos seus serviços aparecem aqui." (Mobile)
- M3 - "Não foi possível atualizar a solicitação."
- M4 - "Sua solicitação foi aceita!" (push)

**Fluxo principal:**
1. Usuário abre o sino → lista carregada.
2. Clica em "Aceitar" ou "Recusar" → `PUT /solicitacoes/:cod`.

**Fluxos alternativos:**
- Erro → M3.

**Implementação (referência técnica):**
- Endpoints: `GET /solicitacoes/prestador/:cpf`, `GET /solicitacoes/usuario/:cpf`, `GET /solicitacoes-ong/usuario/:cpf`, `GET /conversas/usuario/:cpf`, `PUT /solicitacoes/:cod`, `PUT /solicitacoes/:cod/lida`.
- Tabelas: `Mutuo_Solicitacao`, `Mutuo_SolicitacaoONG`.
- Arquivos: `web/usuárioComum/notificacoesMutuo.html`; `lib/notificacoes.dart`.

**Observações:** na Web, "marcar todas como lidas" é só visual (não chama a API). O Mobile não mostra "Meus pedidos".

---

### 4.30 — Tela de Interesse (ONG)
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.26

**História de usuário:**
Como ONG,
quero ver os voluntários interessados nas minhas atividades,
para aceitar ou recusar a participação.

**Critérios de aceite (conforme o código):**
- Web (`notificacoesOng.html`): solicitações recebidas + mensagens; "Aceitar", "Recusar", "Mensagem"; contador de pendentes.
- Mobile: mesma tela `Notificacoes` no modo ONG ("Solicitações de voluntários pelas suas atividades aparecem aqui."); também em "Solicitações recebidas" no perfil da ONG.

**Regras de negócio:**
- R1 - Mesmo comportamento de 4.29, na tabela `Mutuo_SolicitacaoONG`.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhuma solicitação recebida." / "Nenhuma mensagem ainda."
- M2 - "Não foi possível atualizar a solicitação."
- M3 - "Nenhuma solicitação recebida ainda." (Mobile, perfil)

**Fluxo principal:**
1. ONG abre "Notificações"/"Solicitações" → responde → `PUT /solicitacoes-ong/:cod`.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /solicitacoes-ong/prestador/:cnpj`, `PUT /solicitacoes-ong/:cod`, `PUT /solicitacoes-ong/:cod/lida`, `GET /solicitacoes-ong/naolidas/:cnpj`.
- Tabelas: `Mutuo_SolicitacaoONG`.
- Arquivos: `web/usuárioOng/notificacoesOng.html`; `lib/notificacoes.dart`, `lib/perfilOng.dart`, `lib/inicialOng.dart`.

**Observações:** —

---

### 4.31 — Cancelar Solicitação
**Status:** ❌
**Plataformas:** —
**Correspondência na documentação atual:** 2.9 (Cancelar Solicitação)

**História de usuário:**
Como usuário que fez uma solicitação,
quero cancelá-la,
para desistir antes de o serviço ser realizado.

**Critérios de aceite (conforme o código):**
- Não encontrado. Não existe rota nem botão para o solicitante cancelar.

**Regras de negócio:**
- —

**Mensagens do sistema (texto exato encontrado no código):**
- —

**Fluxo principal:**
- —

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: — Tabelas: — Arquivos: —

**Observações:** o mais próximo existente é o prestador **recusar** (4.29/4.30), que grava `statusExecucao = 'Cancelado'` na Web, e o admin alterar o status pelo Desktop (4.54).

---

### 4.32 — Confirmar Realização do Serviço
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.21 / 2.9 (Validar Serviço)

**História de usuário:**
Como quem recebeu o serviço (usuário) ou como ONG que recebeu o voluntário,
quero confirmar que a atividade foi realizada,
para que os pontos sejam transferidos.

**Critérios de aceite (conforme o código):**
- Usuário: aba "Confirmar serviços" do perfil lista solicitações **aceitas** e ainda não realizadas, feitas por ele; botão "Confirmar realização".
- ONG (Web): aba "Confirmar serviços" do perfil lista voluntários aceitos; botão de confirmar.
- Após confirmar, abre a avaliação (4.34).

**Regras de negócio:**
- R1 - Só solicitações `Aceita` e com `statusExecucao != 'Realizada'`.
- R2 - Transação com bloqueio de linha (`FOR UPDATE`): marca `Realizada`, grava `dataConclusao`, transfere os pontos (ver 4.33).
- R3 - Não é possível confirmar duas vezes.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Confirmar a realização deste serviço? Os pontos serão transferidos." (Web)
- M2 - "Serviço confirmado! Pontos transferidos." (Web) / "Serviço confirmado! Pontos atualizados." (Mobile)
- M3 - "Este serviço já foi confirmado." / "Solicitação não encontrada." (API)
- M4 - "Não foi possível confirmar o serviço." (Web) / "Não foi possível confirmar a realização." (Mobile)

**Fluxo principal:**
1. Usuário/ONG abre "Confirmar serviços" → clica em confirmar → `PUT /solicitacoes/:cod/confirmar` ou `PUT /solicitacoes-ong/:cod/confirmar`.
2. Pontos transferidos → modal de avaliação.

**Fluxos alternativos:**
- Já confirmado → M3.

**Implementação (referência técnica):**
- Endpoints: `GET /solicitacoes/confirmar/:cpf`, `PUT /solicitacoes/:cod/confirmar`, `GET /solicitacoes-ong/confirmar/:cnpj`, `PUT /solicitacoes-ong/:cod/confirmar`.
- Tabelas: `Mutuo_Solicitacao`, `Mutuo_SolicitacaoONG`, `Mutuo_Usuario`, `Mutuo_ONG`.
- Arquivos: `web/usuárioComum/perfilMutuo.html`, `web/usuárioOng/perfilOngGMutuo.html`; `lib/perfil.dart`; `db.js` (`confirmarSolicitacao`, `confirmarSolicitacaoOng`).

**Observações:** no **Mobile só o usuário** confirma; o app da ONG não tem confirmação de realização (nem avaliação). A ONG só confirma pela Web.

---

### 4.33 — Confirmação de Pontos (sistema de créditos sociais)
**Status:** ✅
**Plataformas:** Web, Mobile, Desktop
**Correspondência na documentação atual:** 2.5.23

**História de usuário:**
Como participante,
quero acumular e usar pontos pelas trocas,
para ser recompensado pelo trabalho voluntário.

**Critérios de aceite (conforme o código):**
- Saldo exibido no perfil (Web e Mobile) e no painel inicial.
- Web: "Este mês" com pontos recebidos e gastos.
- Desktop: admin pode editar pontos do usuário e da solicitação; card "Total de Pontos".

**Regras de negócio:**
- R1 - Usuário começa com **20 pontos**; ONG com **0**.
- R2 - Cada serviço vale de 10 a 50 pontos (definido por quem cadastra).
- R3 - Troca entre usuários: ao confirmar, o **solicitante perde** e o **prestador ganha** os pontos do serviço.
- R4 - Atividade de ONG: ao confirmar, a **ONG perde** e o **voluntário ganha** os pontos.
- R5 - Bônus mensal da ONG: +500 pontos uma vez por mês, aplicado ao abrir o perfil (`GET /ongs/:cnpj`), só se a ONG tiver até 1000 pontos.
- R6 - Não há verificação de saldo: o saldo pode ficar negativo.
- R7 - A movimentação do mês considera `dataConclusao` no mês corrente.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Falha ao atualizar pontos dos usuários." / "Falha ao atualizar pontos." (API)
- M2 - "Pontos disponíveis"

**Fluxo principal:**
1. Confirmação (4.32) → transação de pontos → saldo atualizado.

**Fluxos alternativos:**
- Falha → rollback da transação.

**Implementação (referência técnica):**
- Endpoints: `PUT /solicitacoes/:cod/confirmar`, `PUT /solicitacoes-ong/:cod/confirmar`, `GET /usuarios/:cpf/movimentacao`, `GET /ongs/:cnpj/movimentacao`, `GET /usuarios/:cpf/dashboard`, `GET /ongs/:cnpj`, `PUT /usuarios/:cpf` (admin), `GET /stats/pontos`.
- Tabelas: `Mutuo_Usuario.pontos`, `Mutuo_ONG.pontos`, `Mutuo_ONG.ultimoBonusMensal`, `Mutuo_Solicitacao.pontos`, `Mutuo_SolicitacaoONG.pontos`.
- Arquivos: `db.js` (`confirmarSolicitacao`, `confirmarSolicitacaoOng`, `verificarBonusMensalOng`, `getMovimentacaoMensal`, `getMovimentacaoMensalOng`); telas de perfil.

**Observações:** a coluna `horasVoluntarias` do usuário só é alterada manualmente pelo admin; o painel calcula as horas a partir das solicitações realizadas. As páginas "Como usar" dizem que "Os pontos de cada serviço serão determinados por nossa equipe", mas no código quem cadastra escolhe o valor.

---

### 4.34 — Avaliação
**Status:** 🟡
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.24 (Avaliação de Usuários) / 2.9 (Avaliar Usuário/Serviço)

**História de usuário:**
Como usuário que recebeu um serviço,
quero dar uma nota de 1 a 5 estrelas,
para ajudar outras pessoas a escolher.

**Critérios de aceite (conforme o código):**
- Logo após confirmar a realização, abre o modal "Avalie o serviço" (Web) / "Avaliar serviço" (Mobile) com 5 estrelas.
- ONG (Web): modal "Avalie o voluntário" após confirmar.
- A nota aparece no card do serviço ("★ 4.5 (N avaliações)").

**Regras de negócio:**
- R1 - Cada solicitação só pode ser avaliada uma vez (`avaliado = 1`).
- R2 - Média ponderada: `(nota_atual × qtd + nova) / (qtd + 1)`, uma casa decimal.
- R3 - A nota individual fica na solicitação (`nota`).

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Selecione uma nota de 1 a 5 estrelas."
- M2 - "Avaliação enviada, obrigado!" (Web) / "Avaliação registrada!" (Mobile)
- M3 - "Este serviço já foi avaliado." (API)
- M4 - "Não foi possível enviar a avaliação." / "Não foi possível registrar a avaliação."

**Fluxo principal:**
1. Confirmação → modal → escolhe estrelas → `POST /solicitacoes/:cod/avaliar` (ou `/solicitacoes-ong/:cod/avaliar`).

**Fluxos alternativos:**
- Sem nota → M1. Já avaliado → M3.

**Implementação (referência técnica):**
- Endpoints: `POST /solicitacoes/:cod/avaliar`, `POST /solicitacoes-ong/:cod/avaliar`.
- Tabelas: `Mutuo_Servico` (`nota`, `avaliacoes`), `Mutuo_ServicoOng` (`nota`, `avaliacoes`), `Mutuo_Solicitacao`/`Mutuo_SolicitacaoONG` (`avaliado`, `nota`).
- Arquivos: `web/usuárioComum/perfilMutuo.html`, `web/usuárioOng/perfilOngGMutuo.html`; `lib/perfil.dart`; `db.js` (`avaliarSolicitacao`, `avaliarSolicitacaoOng`).

**Observações:** parcial porque (1) o que se avalia é o **serviço**, não o usuário; (2) a ONG "avalia o voluntário", mas a nota é gravada na média da **própria atividade da ONG** (`Mutuo_ServicoOng`), não no voluntário; (3) o voluntário não avalia a ONG; (4) a avaliação só é oferecida logo após confirmar — se o modal for fechado, não há outro ponto de entrada; (5) "Média de avaliações" do perfil é fixa (5.0).

---

### 4.35 — Histórico de Serviços
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.22

**História de usuário:**
Como usuário ou ONG,
quero ver as trocas já realizadas,
para acompanhar meu histórico.

**Critérios de aceite (conforme o código):**
- Usuário: "Histórico de trocas" com "Serviços prestados" (serviços próprios realizados + participações em ONGs, na Web), "Serviços utilizados" (serviços que solicitou e foram realizados) e "Confirmar serviços".
- ONG (Web): "Serviços recebidos" (voluntários que concluíram, com nota) e "Confirmar serviços".
- Mostra nome do serviço, outra parte, pontos, data e estrelas.

**Regras de negócio:**
- R1 - Só itens com `statusExecucao = 'Realizada'` entram em prestados/utilizados.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhum serviço prestado ainda." / "Nenhum serviço utilizado ainda." / "Nenhum serviço recebido ainda."
- M2 - "Não avaliado"

**Fluxo principal:**
1. Usuário troca a aba do histórico.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /solicitacoes/prestador/:cpf`, `GET /solicitacoes/usuario/:cpf`, `GET /solicitacoes-ong/usuario/:cpf`, `GET /solicitacoes-ong/recebidos/:cnpj`.
- Tabelas: `Mutuo_Solicitacao`, `Mutuo_SolicitacaoONG`.
- Arquivos: `web/usuárioComum/perfilMutuo.html`, `web/usuárioOng/perfilOngGMutuo.html`; `lib/perfil.dart`.

**Observações:** o app da ONG não tem histórico de atividades realizadas (só o número "Atividades realizadas").

---

### 4.36 — Chat
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.19 / 2.9 (Enviar Mensagem)

**História de usuário:**
Como usuário ou ONG,
quero conversar com outra conta,
para combinar detalhes da troca.

**Critérios de aceite (conforme o código):**
- Lista de conversas com foto, nome, prévia da última mensagem, horário e contador de não lidas; busca por nome.
- Conversa aberta com bolhas, divisores de data, envio por Enter/botão.
- Conversas iniciadas pelos botões "Tirar dúvidas", "Mensagem" (solicitações) ou "Enviar mensagem".
- Entrega em tempo real (Socket.IO); marcação de lida; badge de não lidas no menu "Chat".
- "Limpar conversa"/"Apagar conversa": some só para quem limpou.
- Usuário ↔ usuário, usuário ↔ ONG.

**Regras de negócio:**
- R1 - Um par de participantes tem uma única conversa (ordem normalizada; chave única).
- R2 - Ao abrir a conversa, mensagens do outro participante viram lidas e o outro lado é avisado (`conversa:lida`).
- R3 - Mensagem nova gera push FCM para o destinatário (título = nome do remetente; corpo = texto).
- R4 - Limpar grava `limpo_em_participante_N`; mensagens anteriores somem só para aquela conta.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhuma conversa ainda" / "Nenhuma mensagem ainda"
- M2 - "As mensagens vão desaparecer só do seu lado. A outra conta continua vendo o histórico normalmente. Deseja apagar esta conversa?" (Web)
- M3 - "Limpar conversa" + "As mensagens vão desaparecer só do seu lado. A outra conta continua vendo o histórico normalmente." (Mobile)
- M4 - "Não foi possível abrir o chat." (Mobile)
- M5 - "Não foi possível apagar a conversa." (Web) / "Não foi possível limpar a conversa." (Mobile)
- M6 - "Envie a primeira mensagem para <nome>" (Mobile)
- M7 - "Fale com ONGs e usuários pelos botões de contato nas telas de serviços." (Mobile)
- M8 - "Essa conta não participa dessa conversa." (API)

**Fluxo principal:**
1. Usuário clica em "Tirar dúvidas" → `POST /conversas` (busca ou cria) → abre a conversa.
2. Mensagens carregadas por `GET /conversas/:id/mensagens`; envio pelo evento `mensagem:enviar`.
3. Destinatário recebe `mensagem:nova` (ou push, se o app estiver fechado).

**Fluxos alternativos:**
- Limpar conversa → `PUT /conversas/:id/limpar`.

**Implementação (referência técnica):**
- Endpoints: `POST /conversas`, `GET /conversas/:tipo/:id`, `GET /conversas/:conversaId/mensagens`, `PUT /conversas/:conversaId/limpar`; eventos Socket.IO. (`POST /conversas/:id/mensagens` e `PATCH /conversas/:id/lida` existem, mas os fronts usam o socket.)
- Tabelas: `Mutuo_Conversa`, `Mutuo_Mensagem`, `Mutuo_DispositivoToken`.
- Arquivos: `web/chat-socket.js`, `web/usuárioComum/chatMutuo.html`, `web/usuárioOng/chatOng.html` (Web); `lib/chat.dart`, `lib/conversaChat.dart`, `lib/models/conversa.dart`, `lib/models/mensagem.dart`, `lib/services/chat_socket_service.dart`, `lib/services/chat_sessao_service.dart`, `lib/widgets/chat_badge_icon.dart` (Mobile).

**Observações:** não há autenticação no socket (o evento `identificar` confia no tipo/id enviados) nem na leitura das mensagens (ver seção 9).

---

### 4.37 — Notificações (tempo real, push e badges)
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.9 (Notificação)

**História de usuário:**
Como usuário ou ONG,
quero ser avisado de novas solicitações, respostas e mensagens,
para responder rapidamente.

**Critérios de aceite (conforme o código):**
- Web: badge no sino (solicitações não lidas) e no "Chat" (mensagens não lidas), atualizado por socket.
- Mobile: badge no sino/chat (`ValueNotifier`), notificação local com o app aberto ("Nova solicitação" / mensagem), push FCM com o app em segundo plano ou fechado; tocar abre a conversa ou a tela de solicitações.
- Eventos: nova solicitação (para o prestador/ONG), solicitação aceita/recusada (para o solicitante), nova mensagem.

**Regras de negócio:**
- R1 - O token FCM do aparelho é registrado após o login (`POST /notificacoes/token`), com upsert por token.
- R2 - Tokens recusados pelo Firebase são apagados automaticamente.
- R3 - Mensagem da conversa já aberta não gera notificação local.
- R4 - Sem `firebase-service-account.json`, o push fica desativado e o resto funciona.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nova solicitação" / "Você recebeu uma nova solicitação de serviço." (notificação local Mobile)
- M2 - "Quer solicitar seu serviço \"<serviço>\"" / "Quer participar de \"<atividade>\"" (push)
- M3 - "Sua solicitação foi aceita!" / "Sua solicitação foi recusada." (push)
- M4 - Canal Android "Mensagens" — "Mensagens novas do chat do Mútuo".

**Fluxo principal:**
1. Evento na API → `io.to('<tipo>:<id>').emit(...)` + `enviarPush(...)`.
2. Front atualiza badge / mostra notificação.

**Fluxos alternativos:**
- App fechado → push do sistema; toque abre a tela certa.

**Implementação (referência técnica):**
- Endpoints: `POST /notificacoes/token`, `GET /solicitacoes/naolidas/:cpf`, `GET /solicitacoes-ong/naolidas/:cnpj`, `PUT /solicitacoes/:cod/lida`, `PUT /solicitacoes-ong/:cod/lida`, `GET /conversas/:tipo/:id`.
- Tabelas: `Mutuo_DispositivoToken`, colunas `lida`.
- Arquivos: `web/funcoes.js` (`atualizarBadgeNotificacoes`, `atualizarBadgeNotificacoesOng`), `web/chat-socket.js`; `lib/main.dart`, `lib/services/push_service.dart`, `lib/services/notificacao_local_service.dart`, `lib/services/solicitacao_sessao_service.dart`, `lib/widgets/notificacao_badge_icon.dart`; `index.js` (`enviarPush`).

**Observações:** push só no Android (não há `GoogleService-Info.plist` do iOS). Não há envio de e-mail para esses eventos. Na home Web da ONG, o atalho "Notificações" mostra o número **3** fixo no HTML.

---

### 4.38 — Contato (formulário por e-mail)
**Status:** 🟡
**Plataformas:** Web
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como usuário ou ONG,
quero enviar uma mensagem para a equipe do Mútuo,
para tirar dúvidas ou dar sugestões.

**Critérios de aceite (conforme o código):**
- Página "Contato" com e-mail e WhatsApp da equipe, horário de atendimento e formulário (nome, e-mail, mensagem).
- Usuário: o formulário chama `POST /contato`, que envia e-mail pelo Brevo com "responder para" o e-mail informado.

**Regras de negócio:**
- R1 - Todos os campos obrigatórios; e-mail válido; nome até 120 e mensagem até 5000 caracteres.
- R2 - Campos escapados antes de entrar no HTML do e-mail.
- R3 - Limite de 10 envios por IP a cada 15 min.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Mensagem enviada com sucesso!"
- M2 - "Não foi possível enviar sua mensagem agora. Tente novamente em instantes."
- M3 - "Preencha todos os campos." / "Informe um e-mail válido." / "Mensagem grande demais." / "Não foi possível enviar o e-mail." (API)

**Fluxo principal:**
1. Usuário preenche e envia → `POST /contato` → M1.

**Fluxos alternativos:**
- Erro → M2/M3.

**Implementação (referência técnica):**
- Endpoints: `POST /contato`.
- Tabelas: —
- Arquivos: `web/usuárioComum/contatoMutuo.html`, `web/usuárioOng/contatoOng.html`.

**Observações:** parcial porque o formulário da **ONG** (`contatoOng.html`) não tem script de envio (o `<form>` não chama a API) e o Mobile não tem tela de contato. Os contatos exibidos (e-mail/WhatsApp) são fixos no HTML.

---

### 4.39 — Gerar Certificado
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.27 / 2.9 (Gerar Certificado)

**História de usuário:**
Como voluntário,
quero gerar o certificado das atividades concluídas em ONGs,
para comprovar minhas horas de voluntariado.

**Critérios de aceite (conforme o código):**
- Tela "Meus certificados": resumo (serviços concluídos, ONGs ajudadas, pontos acumulados) e lista agrupada por mês/ano, com ONG, horas, pontos e data.
- Botão "Gerar certificado" abre o PDF (Web em nova aba; Mobile no app externo).
- PDF A4 paisagem com nome do voluntário, atividade, ONG, horas, data de conclusão, código de verificação e QR code.

**Regras de negócio:**
- R1 - Só atividades de **ONG** com `statusExecucao = 'Realizada'` geram certificado (trocas entre usuários não geram).
- R2 - O código de verificação (UUID) é criado na primeira emissão e reutilizado depois.
- R3 - O QR code aponta para `<SITE_URL_PUBLICA>/verificarCertificado.html?codigo=<código>`; sem a variável, o PDF sai sem QR.
- R4 - Dados escapados antes de entrar no template.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Certificado não encontrado." (API)
- M2 - "Não foi possível carregar seus certificados." (Web)
- M3 - "Não foi possível abrir o certificado." / "Erro ao gerar certificado: <erro>" (Mobile)
- M4 - "Você ainda não concluiu nenhum serviço voluntário" (Mobile)

**Fluxo principal:**
1. Usuário abre "Certificados" → `GET /certificados/:cpf`.
2. Clica em "Gerar certificado" → `GET /certificados/:cpf/:codSolicitacao/pdf`.

**Fluxos alternativos:**
- Solicitação não realizada/inexistente → M1.

**Implementação (referência técnica):**
- Endpoints: `GET /certificados/:cpf`, `GET /certificados/:cpf/:codSolicitacao/pdf`.
- Tabelas: `Mutuo_SolicitacaoONG` (`codigoVerificacao`), `Mutuo_ServicoOng`, `Mutuo_ONG`, `Mutuo_Usuario`.
- Arquivos: `web/usuárioComum/certificadosMutuo.html`; `lib/certificadosUsuario.dart`; `mutuo-api/templates/certificado.html`, `index.js` (Puppeteer + `qrcode`), `db.js` (`buscarCertificadosPorUsuario`, `buscarDadosCertificado`).

**Observações:** cada PDF abre um Chrome headless novo (sem cache).

---

### 4.40 — Certificados emitidos (ONG)
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** Nova (complementa 2.5.27)

**História de usuário:**
Como ONG,
quero ver os voluntários que concluíram minhas atividades,
para acompanhar os certificados emitidos.

**Critérios de aceite (conforme o código):**
- Resumo: total de voluntários, certificados emitidos (com código gerado), serviços concluídos e pontos distribuídos.
- Tabela "Voluntários certificados": voluntário (iniciais + nome), tipo de serviço (foco), data de conclusão, pontos; busca por nome; contagem "Exibindo X de Y certificados".

**Regras de negócio:**
- R1 - Considera atividades da ONG com `statusExecucao = 'Realizada'`.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhum certificado emitido ainda." / "Nenhum voluntário encontrado"
- M2 - "Não foi possível carregar os certificados."

**Fluxo principal:**
1. ONG abre "Certificados" → `GET /certificados/ong/:cnpj`.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /certificados/ong/:cnpj`.
- Tabelas: `Mutuo_SolicitacaoONG`, `Mutuo_ServicoOng`, `Mutuo_Usuario`.
- Arquivos: `web/usuárioOng/certificadosOng.html`; `lib/certificadosOng.dart`; `db.js` (`buscarCertificadosPorOng`).

**Observações:** a ONG não gera o PDF; só consulta. O texto inicial "Exibindo 8 de 190 certificados" é fixo no HTML até a lista carregar.

---

### 4.41 — Verificar autenticidade do certificado (código/QR)
**Status:** ✅
**Plataformas:** Web
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como qualquer pessoa (ex.: empresa ou escola),
quero conferir se um certificado é verdadeiro,
para confiar nas horas de voluntariado informadas.

**Critérios de aceite (conforme o código):**
- Página pública "Verificar certificado", acessível pela landing page ("Verificar Certificado").
- Campo para o código; ao abrir pelo QR code, o código já vem preenchido e é verificado automaticamente.
- Válido: mostra voluntário, serviço, ONG, carga horária e data de conclusão.

**Regras de negócio:**
- R1 - Rota pública; o código é um UUID.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Certificado válido"
- M2 - "Certificado não encontrado" + "Verifique se o código foi digitado corretamente e tente novamente."
- M3 - "Erro ao verificar" + "Não foi possível conectar ao servidor. Tente novamente."

**Fluxo principal:**
1. Pessoa digita o código ou lê o QR → `GET /verificar/:codigo` → M1 com os dados.

**Fluxos alternativos:**
- Código inexistente → M2. API indisponível/cold start → M3.

**Implementação (referência técnica):**
- Endpoints: `GET /verificar/:codigo`.
- Tabelas: `Mutuo_SolicitacaoONG`, `Mutuo_ServicoOng`, `Mutuo_ONG`, `Mutuo_Usuario`.
- Arquivos: `web/verificarCertificado.html`; `db.js` (`verificarCertificado`).

**Observações:** após exclusão de conta, o voluntário aparece como "Usuário removido".

---

### 4.42 — Tela de Apresentação
**Status:** 🟠
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.14

**História de usuário:**
Como visitante,
quero conhecer o Mútuo antes de me cadastrar,
para entender a proposta da plataforma.

**Critérios de aceite (conforme o código):**
- Web (`InicialMutuo.html`, aberta por `index.html`): menu (Início, Funcionalidades, Avaliações, Sobre, Verificar Certificado), botões "Entrar" e "Cadastrar", seções de funcionalidades, vitrine, depoimentos, chamada final e rodapé.
- Mobile (`Carregamento`): tela de abertura com frases alternadas ("Conectando pessoas, simplificando oportunidades." etc.) e botão para o login ("Conheça nossos serviços").

**Regras de negócio:**
- R1 - Não consulta a API.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Transforme o mundo através da troca" (título da landing)

**Fluxo principal:**
1. Visitante abre o site/app → apresentação → Entrar/Cadastrar.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: —
- Tabelas: —
- Arquivos: `web/index.html`, `web/InicialMutuo.html`; `lib/carregamento.dart`.

**Observações:** 🟠 a landing Web exibe números fixos ("10k+ Usuários ativos", "25k+ Trocas realizadas", "50+ Cidades", "98% Satisfação"), seis depoimentos fixos e contatos fictícios no rodapé ("contato@mutuo.com", "(11) 99999-9999"). Newsletter, redes sociais e links do rodapé ("Termos de Uso", "Privacidade" etc.) não têm ação; os botões "Começar Agora — É Grátis" e "Ver Mais Avaliações" não têm ação. O `meta refresh` de `web/index.html` aponta para `inicialMutuo.html` (minúsculo) — o redirecionamento por JavaScript usa o nome correto.

---

### 4.43 — Tela Inicial (painel)
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.15

**História de usuário:**
Como usuário ou ONG logado,
quero ver um resumo da minha atividade e atalhos,
para navegar rapidamente.

**Critérios de aceite (conforme o código):**
- **Usuário (Web `homeMutuo.html` / Mobile `InicialUsuario`)**: boas-vindas com o nome; cards "Horas de serviço", "Trabalhos concluídos", "Pontos", "Plano atual"; frases de inspiração em rotação; acesso rápido (Serviços/Buscar Vagas, ONGs, Chat, Certificados, Notificações, Planos); "Vagas em destaque"; "Perto de você" (Web).
- **ONG (Web `homeOngMutuo.html` / Mobile `InicialOng`)**: boas-vindas; voluntários, avaliação, atividades; acesso rápido (Chat, Certificados, Notificações, Nossos Planos, Meu Perfil); "Adicionados recentemente" (atividades com botão editar); card "Adicionar nova atividade" com limite do plano; no app, selo "ONG verificada" para Premium.
- Navegação inferior no app: Início, Serviços, ONGs, Chat (usuário) / Início, Atividades, Solicitações, Chat (ONG).

**Regras de negócio:**
- R1 - Horas e trabalhos concluídos somam serviços prestados realizados + atividades de ONG realizadas pelo usuário.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Bem-vindo(a), <nome>!" / "Confira as novidades do seu painel hoje" (Mobile)
- M2 - "melhore seu plano" / "aproveite os benefícios" (Web) / "gerenciar assinatura" (Mobile)
- M3 - "Você ainda não cadastrou nenhuma atividade." (Mobile, ONG)
- M4 - "Erro ao carregar suas atividades." (Web, ONG)

**Fluxo principal:**
1. Após o login, a home carrega o painel.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /usuarios/:cpf`, `GET /usuarios/:cpf/estatisticas` (Web), `GET /usuarios/:cpf/dashboard` (Mobile), `GET /servicos-destaque`, `GET /servicos-perto/:cidade`, `GET /ongs/:cnpj`, `GET /servicos/ong/:cnpj`, `GET /ongs/:cnpj/voluntarios-realizados` (Web), `GET /solicitacoes-ong/prestador/:cnpj` (Mobile).
- Tabelas: várias (leitura).
- Arquivos: `web/usuárioComum/homeMutuo.html`, `web/usuárioOng/homeOngMutuo.html`; `lib/inicialUser.dart`, `lib/inicialOng.dart`.

**Observações:** 🟠 na home Web da ONG, "Avaliação" é **5.0** fixo e o atalho de Notificações mostra **3** fixo. A home Web do usuário contém três modais de exemplo fixos ("Aula de culinária", "Passeie com os cachorros", "Aula de ciências") que não são abertos por nenhum botão. No app da ONG, o número de voluntários é calculado no próprio app a partir das solicitações.

---

### 4.44 — Como usar a plataforma
**Status:** ✅
**Plataformas:** Web
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como usuário ou ONG,
quero ler um guia de uso,
para entender cada recurso.

**Critérios de aceite (conforme o código):**
- Página estática com tópicos: Serviços, Voluntários, Chat, Notificações, Perfil, Certificados, Pontos, Confirmação de serviços.

**Regras de negócio:**
- —

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Acesse o aplicativo e descubra como é simples transformar solidariedade em ação!"

**Fluxo principal:**
1. Menu "Mais" → "Como usar a plataforma".

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Arquivos: `web/usuárioComum/comoUsarMutuo.html`, `web/usuárioOng/comoUsarOng.html`.

**Observações:** a versão do **usuário comum** repete o texto voltado à ONG ("Cadastre atividades… para ajudar sua causa", "Edite as informações da sua ONG"). Não existe no Mobile.

---

### 4.45 — Quem somos
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como usuário ou ONG,
quero conhecer quem criou o Mútuo,
para entender o propósito do projeto.

**Critérios de aceite (conforme o código):**
- Texto sobre a origem do projeto e fotos dos fundadores (Elis Meneghin, Manuela Azevedo e Mateus De Julio).

**Regras de negócio:**
- —

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nossos Fundadores"

**Fluxo principal:**
1. Menu → "Quem somos".

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Arquivos: `web/usuárioComum/quemSomosMutuo.html`, `web/usuárioOng/quemSomosOng.html`; `lib/quem_somos.dart`.

**Observações:** conteúdo estático.

---

### 4.46 — Tela de Propaganda do Premium (planos)
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.28

**História de usuário:**
Como usuário ou ONG,
quero comparar o plano gratuito com o Premium,
para decidir se vale assinar.

**Critérios de aceite (conforme o código):**
- Usuário: Gratuito R$ 0,00 e Premium R$ 19,90/mês ("MAIS RECOMENDADO").
- ONG: Gratuito R$ 0,00 e Premium R$ 49,90/mês.
- A tela consulta o plano atual: mostra "Plano atual" no plano ativo, "Assinar agora" (gratuito) ou "Cancelar Premium" (Premium).

**Regras de negócio:**
- R1 - O plano vem de `premium` em `GET /usuarios/:cpf` ou `GET /ongs/:cnpj`.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Escolha o melhor plano para você" / "Escolha o melhor plano para sua ONG"
- M2 - "Não foi possível verificar seu plano."

**Fluxo principal:**
1. Usuário abre "Conheça nossos planos" → escolhe.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /usuarios/:cpf`, `GET /ongs/:cnpj`.
- Arquivos: `web/usuárioComum/planosMutuo.html`, `web/usuárioOng/planosOng.html`; `lib/planosUsuario.dart`, `lib/planosOng.dart`.

**Observações:** os benefícios anunciados variam entre plataformas e nem todos existem no código (ver 4.49).

---

### 4.47 — Tela de Upgrade / Contratar Premium
**Status:** 🟠
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.29 / 2.9 (Contratar Plano Premium)

**História de usuário:**
Como usuário ou ONG,
quero assinar o plano Premium,
para ter os benefícios.

**Critérios de aceite (conforme o código):**
- Tela de checkout com cartão visual animado (nome, número, validade, CVV, bandeira), CPF do titular e resumo do pedido (plano, cobrança mensal, renovação automática, total).
- Ao confirmar, o plano é ativado (`premium = 1`) e o usuário volta ao perfil/planos.

**Regras de negócio:**
- R1 - **Pagamento simulado**: nenhuma cobrança real; os dados do cartão não são enviados à API (a API só recebe `{ premium: 1 }`).
- R2 - Validações no front: nome ≥ 3 caracteres, cartão de 13 a 16 dígitos, validade MM/AA com mês válido, CVV ≥ 3, CPF com 11 dígitos.
- R3 - Web simula 1,4 s de "Processando pagamento...".

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Assinatura confirmada!" (Web) / "Assinatura confirmada! Bem-vindo ao Premium 🎉" (Mobile)
- M2 - "Ambiente de simulação: nenhuma cobrança real será feita e nenhum dado de cartão será armazenado." (Mobile)
- M3 - "Número de cartão inválido." / "Informe a validade no formato MM/AA." / "Mês de validade inválido." / "CVV inválido." / "Informe um CPF válido." / "Informe o nome impresso no cartão." (Web)
- M4 - "Preencha todos os dados de pagamento." (Mobile)
- M5 - "O campo \"premium\" deve ser 0 ou 1." (API)

**Fluxo principal:**
1. Usuário clica em "Assinar agora" → preenche o cartão → confirma.
2. `PUT /usuarios/:cpf/premium` ou `PUT /ongs/:cnpj/premium` com `premium: 1`.

**Fluxos alternativos:**
- Dados inválidos → M3/M4.

**Implementação (referência técnica):**
- Endpoints: `PUT /usuarios/:cpf/premium`, `PUT /ongs/:cnpj/premium`.
- Tabelas: `Mutuo_Usuario.premium`, `Mutuo_ONG.premium`.
- Arquivos: `web/usuárioComum/assinarPremium.html`, `web/usuárioOng/assinarPremiumOng.html`; `lib/checkoutPremiumUsuario.dart`, `lib/checkoutPremiumOng.dart`, `lib/utils/input_formatters.dart`.

**Observações:** as tabelas `Mutuo_UsuarioPremium` e `Mutuo_ONGPremium` (pagamentos) **não** são gravadas pelo checkout; só são lidas pelas rotas de estatística do admin.

---

### 4.48 — Cancelar Premium
**Status:** ✅
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como assinante Premium,
quero cancelar a assinatura,
para voltar ao plano gratuito.

**Critérios de aceite (conforme o código):**
- Na tela de planos, "Cancelar Premium"/"Cancelar assinatura" com confirmação.
- Volta para o plano gratuito imediatamente.

**Regras de negócio:**
- R1 - Grava `premium = 0`. Serviços acima do limite gratuito continuam ativos (não são desativados).

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Plano Premium cancelado! Você agora está no plano gratuito." (Web)
- M2 - "Tem certeza que deseja cancelar seu plano Premium? Você volta pro plano gratuito (até 3 serviços ativos) imediatamente." (Mobile)
- M3 - "Assinatura cancelada. Você voltou ao plano gratuito." / "Assinatura cancelada. Vocês voltaram ao plano gratuito." (Mobile)
- M4 - "Não foi possível cancelar o plano. Tente novamente." (Web) / "Não foi possível cancelar a assinatura." (Mobile)

**Fluxo principal:**
1. Assinante clica em cancelar → confirma → `PUT .../premium` com `premium: 0`.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `PUT /usuarios/:cpf/premium`, `PUT /ongs/:cnpj/premium`.
- Arquivos: `web/usuárioComum/planosMutuo.html`, `web/usuárioOng/planosOng.html`; `lib/planosUsuario.dart`, `lib/planosOng.dart`.

**Observações:** o admin também remove o Premium pelo Desktop (4.55).

---

### 4.49 — Benefícios Premium
**Status:** 🟡
**Plataformas:** Web, Mobile
**Correspondência na documentação atual:** 2.5.30

**História de usuário:**
Como assinante Premium,
quero ter vantagens em relação ao plano gratuito,
para justificar a assinatura.

**Critérios de aceite (conforme o código):**
- Implementados: limite maior de serviços (usuário 8; ONG 10); aparecer em "Vagas em destaque" e "Perto de você"; rótulo "Plano Premium" no perfil; selo "ONG verificada" na home do app; ⭐ ao lado do nome da ONG na tabela do admin.
- Anunciados e **não** implementados: "Suporte prioritário 24h"; "Prioridade nas solicitações de serviços"; "Maior visibilidade nos resultados" além das seções de destaque; para ONG, "800 pontos mensais" (Web) / "Pontos ilimitados" (Mobile) e "Serviços ilimitados".

**Regras de negócio:**
- R1 - Tudo depende da coluna `premium` (0/1).
- R2 - O bônus mensal de pontos da ONG é o mesmo (500) para gratuita e Premium.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "ONG verificada" (Mobile)
- M2 - "Apareça em \"Serviços em destaque\"" / "Apareça em \"Perto de você\"" (Mobile, planos)

**Fluxo principal:**
1. Ao assinar, as regras acima passam a valer.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `POST /servicos`, `POST /servicos/ong`, `GET /servicos-destaque`, `GET /servicos-perto/:cidade`.
- Tabelas: `Mutuo_Usuario.premium`, `Mutuo_ONG.premium`.
- Arquivos: `db.js` (`getServicosDestaque`, `getServicosPertoDeVoce`, `isUsuarioPremium`, `isOngPremium`); telas de planos e home.

**Observações:** os textos de benefícios divergem entre Web e Mobile (ex.: plano gratuito da ONG na Web diz "300 pontos mensais"; Premium Web "800 pontos mensais"; Premium Mobile "Pontos ilimitados"; ambos dizem "Serviços ilimitados", mas a API limita a 10).

---

### 4.50 — Dashboard administrativo
**Status:** ✅
**Plataformas:** Desktop
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como administrador do sistema,
quero ver os números gerais da plataforma,
para acompanhar o uso.

**Critérios de aceite (conforme o código):**
- Tela "Gerenciamento do Sistema": cards "Usuários Ativos", "ONGs Ativas", "Serviços Realizados", "Horas Voluntárias" e gráfico de barras (Chart.js) com os mesmos números.
- Menu lateral: Início, Usuários, ONGS, Serviços, Solicitações, Revisão, Premium; nome do admin; "Sair"; ícones de tema e perfil.

**Regras de negócio:**
- R1 - "Serviços Realizados" soma solicitações realizadas de usuários e de ONGs; "Horas Voluntárias" soma as horas dessas solicitações.
- R2 - Todas as rotas exigem token de admin.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Erro!" (card que falhou)

**Fluxo principal:**
1. Após o login, a janela "Início" carrega os quatro totais.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /stats/usuarios`, `GET /stats/ongs`, `GET /stats/servicos`, `GET /stats/horas`.
- Arquivos: `electron/src/views/inicio.html`; `db.js` (`countUsuarios`, `countONGs`, `countServicos`, `countHoras`).

**Observações:** o gráfico acompanha o tema escuro.

---

### 4.51 — Gerenciar Usuários
**Status:** ✅
**Plataformas:** Desktop
**Correspondência na documentação atual:** Nova (cobre 2.5.4, 2.5.5 e 2.5.6 pelo lado do admin)

**História de usuário:**
Como administrador do sistema,
quero listar, cadastrar e editar usuários,
para manter a base correta.

**Critérios de aceite (conforme o código):**
- Cards: Ativos, Inativos, Total de Pontos.
- Tabela: Nome, Email, CPF, Status (ativo 0/1), Pontos, Horas, Cadastro.
- Duplo clique edita Status, Pontos e Horas → "Salvar".
- "+ Adicionar Usuário" abre o modal de cadastro (com CEP automático).
- Busca por nome ou CPF.

**Regras de negócio:**
- R1 - Inativar (`ativo = 0`) impede o login.
- R2 - Apenas uma linha em edição por vez.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Salve a linha que já está em edição primeiro."
- M2 - "Erro ao salvar: <erro>"
- M3 - "Usuário cadastrado com sucesso!"

**Fluxo principal:**
1. Admin abre "Usuários" → edita ou adiciona.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /usuarios`, `PUT /usuarios/:cpf`, `POST /usuarios`, `GET /stats/usuarios`, `GET /stats/usuarios-inativos`, `GET /stats/pontos`.
- Arquivos: `electron/src/views/usuarios.html`.

**Observações:** os valores de status e pontos são editados como número livre (sem validação além de `min`/`max` do input).

---

### 4.52 — Gerenciar ONGs
**Status:** ✅
**Plataformas:** Desktop
**Correspondência na documentação atual:** Nova (cobre 2.5.1, 2.5.2 e 2.5.3 pelo lado do admin)

**História de usuário:**
Como administrador do sistema,
quero listar, cadastrar e editar ONGs,
para manter a base correta.

**Critérios de aceite (conforme o código):**
- Cards: ONGs ativas, inativas e Premium.
- Tabela: ONG (⭐ se Premium), CNPJ, Responsável, Foco, Status.
- Duplo clique edita Responsável, Foco e Status.
- "+ Adicionar ONG" (modal) e busca por nome ou CNPJ.

**Regras de negócio:**
- R1 - Inativar impede o login da ONG.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhuma ONG encontrada"
- M2 - "ONG cadastrada com sucesso!"

**Fluxo principal:**
1. Admin abre "ONGS" → edita ou adiciona.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /ongs`, `PUT /ongs/:cnpj`, `POST /ongs`, `GET /stats/ongs`, `GET /stats/ongs-inativas`, `GET /stats/premium`.
- Arquivos: `electron/src/views/ongs.html`.

**Observações:** —

---

### 4.53 — Gerenciar Serviços
**Status:** 🟡
**Plataformas:** Desktop
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como administrador do sistema,
quero ver e ajustar os serviços cadastrados,
para corrigir informações.

**Critérios de aceite (conforme o código):**
- Cards: Serviços Realizados, Serviços Cadastrados (ativos), Média de notas ("x.x / 5").
- Tabela: Serviço, Criador, Área, Horas, Status, Nota; duplo clique edita Área, Horas, Status e Nota; busca por nome.

**Regras de negócio:**
- R1 - Rota protegida por token (`PUT /adm/servicos/:cod`).

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhum serviço encontrado"
- M2 - "Resposta inesperada do servidor."

**Fluxo principal:**
1. Admin abre "Serviços" → edita → "Salvar".

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /servicos`, `PUT /adm/servicos/:cod`, `GET /stats/servicos`, `GET /stats/servicos-cadastrados`, `GET /stats/media-notas`.
- Tabelas: `Mutuo_Servico`.
- Arquivos: `electron/src/views/servicos.html`; `db.js` (`getServicos`, `alterServico`).

**Observações:** parcial porque (1) lista só serviços de **usuários** — atividades de ONGs não aparecem; (2) a alteração grava a nota em uma coluna `avaliacao`, enquanto a listagem lê `nota AS avaliacao` — se a coluna `avaliacao` não existir no banco, a edição falha; (3) a média de notas inclui serviços sem avaliação.

---

### 4.54 — Gerenciar Solicitações
**Status:** 🟡
**Plataformas:** Desktop
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como administrador do sistema,
quero ver e corrigir solicitações,
para resolver problemas entre usuários.

**Critérios de aceite (conforme o código):**
- Cards: Aceitas, Pendentes, Recusadas.
- Tabela: Serviço, Solicitante, Prestador, Status Sol. (Pendente/Aceita/Recusada), Status Ex. (Pendente/Realizada), Data, Pontos; duplo clique edita; busca por serviço.

**Regras de negócio:**
- R1 - Rota protegida por token (`PUT /adm/solicitacoes/:cod`).

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Nenhuma solicitação encontrada"

**Fluxo principal:**
1. Admin abre "Solicitações" → edita → "Salvar".

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /solicitacoes`, `PUT /adm/solicitacoes/:cod`, `GET /stats/aceitas`, `GET /stats/pendentes`, `GET /stats/recusadas`.
- Tabelas: `Mutuo_Solicitacao`.
- Arquivos: `electron/src/views/solicitacoes.html`.

**Observações:** parcial porque só mostra solicitações **entre usuários** (as de ONGs, `Mutuo_SolicitacaoONG`, não aparecem). Marcar "Realizada" pelo admin **não** transfere pontos nem grava `dataConclusao`. O status de execução usado pelos apps é "Não iniciado", mas o select do admin oferece "Pendente".

---

### 4.55 — Gerenciar contas Premium
**Status:** ✅
**Plataformas:** Desktop
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como administrador do sistema,
quero ver as contas Premium e remover o plano quando necessário,
para controlar as assinaturas.

**Critérios de aceite (conforme o código):**
- Cards: ONGs Premium, Usuários Premium, Receita Mensal.
- Tabela: Nome, Tipo (ONG/Usuário), E-mail, botão "Remover" (com confirmação); busca por nome.

**Regras de negócio:**
- R1 - Receita = usuários Premium × R$ 19,90 + ONGs Premium × R$ 49,90 (preços fixos no código da tela).
- R2 - Remover grava `premium = 0`.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Remover Premium?" / "Essa conta perderá os benefícios do plano Premium."
- M2 - "Nenhuma conta premium encontrada."
- M3 - "Não foi possível remover o Premium."

**Fluxo principal:**
1. Admin abre "Premium" → `GET /premium/contas` → "Remover" → `PUT /adm/usuarios/:cpf/premium` ou `PUT /adm/ongs/:cnpj/premium`.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Endpoints: `GET /premium/contas`, `PUT /adm/usuarios/:cpf/premium`, `PUT /adm/ongs/:cnpj/premium`.
- Tabelas: `Mutuo_Usuario`, `Mutuo_ONG`.
- Arquivos: `electron/src/views/premium.html`.

**Observações:** as rotas `GET /premium`, `/stats/premium-total`, `/stats/atrasadas` e `/stats/receita` (baseadas em `Mutuo_UsuarioPremium`/`Mutuo_ONGPremium`, receita = pagamentos × 25) estão expostas no `preload.js`, mas nenhuma tela as usa.

---

### 4.56 — Perfil do administrador (login, senha, novo admin)
**Status:** ✅
**Plataformas:** Desktop
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como administrador do sistema,
quero alterar meu login e senha e cadastrar outros administradores,
para gerenciar o acesso ao painel.

**Critérios de aceite (conforme o código):**
- Tela de perfil com "Mudar Login", "Mudar Senha" (senha atual, nova, confirmação) e "Adicionar Administrador" (login, senha, confirmação), todos em modais.

**Regras de negócio:**
- R1 - O login do admin é sempre o do token (nunca do corpo da requisição).
- R2 - Ao mudar o login, a API devolve um token novo.
- R3 - Senha nova com hash bcrypt; troca exige a senha atual correta.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "Informe o novo login!" / "Informe a senha atual!" / "Informe a nova senha!" / "As senhas não coincidem!" / "Informe um login!" / "Informe uma senha!"
- M2 - "Login alterado!" / "Senha alterada!" / "Administrador cadastrado!"
- M3 - "Senha atual incorreta" (API)

**Fluxo principal:**
1. Admin abre o perfil → escolhe a ação → confirma.

**Fluxos alternativos:**
- Senha atual errada → M3.

**Implementação (referência técnica):**
- Endpoints: `PUT /adm/login`, `PUT /adm/senha`, `POST /adm/cadastrar`.
- Tabelas: `Mutuo_Adm`.
- Arquivos: `electron/src/views/perfil.html`; `db.js` (`alterarLoginAdm`, `alterarSenhaAdm`, `cadastrarAdm`).

**Observações:** não há listagem nem remoção de administradores.

---

### 4.57 — Modo escuro
**Status:** ✅
**Plataformas:** Desktop
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como administrador,
quero alternar entre tema claro e escuro,
para trabalhar com mais conforto.

**Critérios de aceite (conforme o código):**
- Ícone na barra superior alterna o tema; a escolha fica no `localStorage` e vale para todas as telas internas; o gráfico e os modais acompanham.

**Regras de negócio:**
- R1 - Tema aplicado antes do carregamento da página para evitar "piscar".

**Mensagens do sistema (texto exato encontrado no código):**
- —

**Fluxo principal:**
1. Admin clica no ícone de tema.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Arquivos: `electron/src/views/tema.js`, `electron/src/views/style.css` (incluído em inicio, usuarios, ongs, servicos, solicitacoes, revisao, premium e perfil).

**Observações:** a tela de login do Desktop não tem modo escuro. Web e Mobile não têm modo escuro.

---

### 4.58 — Preenchimento de endereço por CEP
**Status:** ✅
**Plataformas:** Web, Mobile, Desktop
**Correspondência na documentação atual:** Nova

**História de usuário:**
Como pessoa se cadastrando,
quero que o endereço seja preenchido pelo CEP,
para ganhar tempo e evitar erros.

**Critérios de aceite (conforme o código):**
- Ao completar 8 dígitos (Web/Mobile) ou sair do campo (Desktop), consulta o ViaCEP e preenche endereço, bairro, cidade e UF.

**Regras de negócio:**
- R1 - Se o CEP não existir, o usuário preenche manualmente.

**Mensagens do sistema (texto exato encontrado no código):**
- M1 - "CEP não encontrado." (Web) / "CEP não encontrado" (Mobile e Desktop)
- M2 - "Não foi possível buscar o CEP. Preencha manualmente." (Web)
- M3 - "Erro ao buscar CEP. Verifique sua conexão." (Mobile) / "Erro ao buscar CEP" (Desktop)
- M4 - "CEP deve ter 8 dígitos" (Mobile)

**Fluxo principal:**
1. Usuário digita o CEP → `https://viacep.com.br/ws/<cep>/json/` → campos preenchidos.

**Fluxos alternativos:**
- —

**Implementação (referência técnica):**
- Arquivos: `web/usuárioComum/cadastroLocUsuario.html`, `web/usuárioOng/cadastroLocOng.html`; `lib/cadastro_endereco.dart`; `electron/src/views/usuarios.html`, `electron/src/views/ongs.html`.

**Observações:** o CEP do usuário é gravado; o CEP da ONG não é gravado (não existe no `INSERT` de `cadastrarOng`).

---

## 5. Telas por plataforma

### 5.1 Web
| Tela | Arquivo | Perfil | O que faz |
|---|---|---|---|
| Redirecionamento | `web/index.html` | Visitante | Redireciona para `InicialMutuo.html`. |
| Apresentação (landing) | `web/InicialMutuo.html` | Visitante | Página institucional estática com números e depoimentos fixos; links Entrar/Cadastrar/Verificar Certificado. |
| Login | `web/login.html` | Visitante | Login de usuário ou ONG; leva à confirmação de e-mail ou à recuperação de senha. |
| Cadastro — etapa 1 | `web/cadastro.html` | Visitante | Nome, e-mail, telefone e tipo de conta. |
| Cadastro concluído | `web/cadastroConfirmacao.html` | — | Mensagem "Cadastro realizado com sucesso!"; **não é usada** por nenhum fluxo. |
| Confirmar e-mail | `web/confirmarEmail.html` | Visitante | Código de 6 dígitos, reenvio com contador. |
| Esqueci minha senha | `web/esqueciSenha.html` | Visitante | 3 etapas: e-mail → código → nova senha. |
| Verificar certificado | `web/verificarCertificado.html` | Visitante | Confere código de certificado (também via QR). |
| Cadastro pessoal | `web/usuárioComum/cadastroPessoal.html` | Visitante | CPF, senha, nascimento, foto. |
| Cadastro endereço (usuário) | `web/usuárioComum/cadastroLocUsuario.html` | Visitante | CEP/endereço e envio do cadastro. |
| Home do usuário | `web/usuárioComum/homeMutuo.html` | Usuário | Painel, acesso rápido, vagas em destaque, perto de você. |
| Serviços | `web/usuárioComum/serviçosMutuo.html` | Usuário | Busca/filtros de serviços de usuários; solicitar; tirar dúvidas. |
| ONGs | `web/usuárioComum/OngsMutuo.html` | Usuário | Busca/filtros de atividades de ONGs; inscrever-se. |
| Perfil público da ONG | `web/usuárioComum/perfilOngMutuo.html` | Usuário | Dados e atividades de uma ONG. |
| Chat | `web/usuárioComum/chatMutuo.html` | Usuário | Conversas em tempo real. |
| Notificações | `web/usuárioComum/notificacoesMutuo.html` | Usuário | Solicitações recebidas (aceitar/recusar), meus pedidos, mensagens. |
| Perfil | `web/usuárioComum/perfilMutuo.html` | Usuário | Dados, foto, pontos, meus serviços, histórico, confirmar/avaliar, LGPD. |
| Adicionar serviço | `web/usuárioComum/adicionarServicoMutuo.html` | Usuário | Cadastro de serviço com moderação. |
| Editar serviço | `web/usuárioComum/editarServicoMutuo.html` | Usuário | Edição de serviço com moderação. |
| Certificados | `web/usuárioComum/certificadosMutuo.html` | Usuário | Resumo e geração de certificados PDF. |
| Planos | `web/usuárioComum/planosMutuo.html` | Usuário | Gratuito × Premium; cancelar Premium. |
| Assinar Premium | `web/usuárioComum/assinarPremium.html` | Usuário | Checkout simulado (R$ 19,90). |
| Contato | `web/usuárioComum/contatoMutuo.html` | Usuário | Formulário enviado por e-mail (Brevo). |
| Como usar | `web/usuárioComum/comoUsarMutuo.html` | Usuário | Guia estático. |
| Quem somos | `web/usuárioComum/quemSomosMutuo.html` | Usuário | Página institucional dos fundadores. |
| Cadastro ONG — dados | `web/usuárioOng/cadastroOng1.html` | Visitante | Nome, CNPJ, senha, fundação, foco, descrição, foto. |
| Cadastro ONG — endereço | `web/usuárioOng/cadastroLocOng.html` | Visitante | CEP/endereço e envio do cadastro. |
| Home da ONG | `web/usuárioOng/homeOngMutuo.html` | ONG | Painel, atalhos, atividades recentes, limite do plano. |
| Perfil da ONG | `web/usuárioOng/perfilOngGMutuo.html` | ONG | Dados, foto, pontos, serviços, recebidos, confirmar/avaliar, LGPD. |
| Adicionar atividade | `web/usuárioOng/adicionarServicoOng.html` | ONG | Cadastro com moderação. |
| Editar atividade | `web/usuárioOng/editarServicoOng.html` | ONG | Edição com moderação e exclusão. |
| Notificações da ONG | `web/usuárioOng/notificacoesOng.html` | ONG | Interesses de voluntários (aceitar/recusar) e mensagens. |
| Chat da ONG | `web/usuárioOng/chatOng.html` | ONG | Conversas em tempo real. |
| Certificados emitidos | `web/usuárioOng/certificadosOng.html` | ONG | Resumo e tabela de voluntários certificados. |
| Planos da ONG | `web/usuárioOng/planosOng.html` | ONG | Gratuito × Premium; cancelar Premium. |
| Assinar Premium ONG | `web/usuárioOng/assinarPremiumOng.html` | ONG | Checkout simulado (R$ 49,90). |
| Contato (ONG) | `web/usuárioOng/contatoOng.html` | ONG | Informações de contato; formulário **sem envio**. |
| Como usar (ONG) | `web/usuárioOng/comoUsarOng.html` | ONG | Guia estático. |
| Quem somos (ONG) | `web/usuárioOng/quemSomosOng.html` | ONG | Página institucional. |

Scripts compartilhados: `web/funcoes.js` (URL da API, foto, badges, inscrição), `web/chat-socket.js` (socket e badge do chat), `web/moderacao.js` (overlay e popup da moderação), `web/navbarUsuarioResponsiva.js` e `web/navbarOngResponsiva.js` (proteção de rota, menu hambúrguer/drawer e "Sair da conta"), `web/navbarOngResponsiva.css`.

### 5.2 Mobile
| Tela | Arquivo | Perfil | O que faz |
|---|---|---|---|
| Inicialização / decisão de sessão | `lib/main.dart` (`_TelaInicial`) | Todos | Retoma a sessão ou abre a apresentação; trata toques em notificações. |
| Apresentação | `lib/carregamento.dart` | Visitante | Splash com frases e botão para o login. |
| Login | `lib/login.dart` | Visitante | E-mail/senha (tenta usuário e depois ONG). |
| Cadastro — etapa 1 | `lib/cadastro.dart` | Visitante | Tipo de conta, nome, e-mail, senha, telefone. |
| Cadastro — etapa 2 | `lib/cadastro_documento.dart` | Visitante | CPF + nascimento ou dados da ONG. |
| Cadastro — etapa 3 | `lib/cadastro_endereco.dart` | Visitante | Endereço com ViaCEP e envio. |
| Confirmar e-mail | `lib/confirmar_email.dart` | Visitante | Código de 6 dígitos e reenvio. |
| Esqueci minha senha | `lib/esqueci_senha.dart` | Visitante | 3 etapas de recuperação. |
| Home do usuário | `lib/inicialUser.dart` | Usuário | Painel, atalhos, vagas em destaque, detalhe da vaga (`DetalheVaga`). |
| Serviços | `lib/servicos.dart` | Usuário | Lista/busca/categorias; detalhe (`DetalheServico`) com solicitar e tirar dúvidas. |
| ONGs | `lib/ongs.dart` | Usuário | Atividades de ONGs; detalhe (`DetalheOng`) com "Quero participar". |
| Perfil do usuário | `lib/perfil.dart` | Usuário | Dados, foto, pontos, serviços (modal de cadastro/edição), histórico, confirmar/avaliar, LGPD. |
| Certificados do usuário | `lib/certificadosUsuario.dart` | Usuário | Resumo e abertura do PDF. |
| Planos (usuário) | `lib/planosUsuario.dart` | Usuário | Gratuito × Premium; cancelar. |
| Checkout (usuário) | `lib/checkoutPremiumUsuario.dart` | Usuário | Pagamento simulado. |
| Home da ONG | `lib/inicialOng.dart` | ONG | Painel, atalhos, atividades recentes, limite. |
| Minhas atividades | `lib/servicosOng.dart` | ONG | Lista/busca de atividades, editar/excluir, status de moderação. |
| Modal de atividade | `lib/widgets/modal_atividade_ong.dart` | ONG | Cadastro/edição de atividade. |
| Perfil da ONG | `lib/perfilOng.dart` | ONG | Dados, foto, pontos, atividades, solicitações recebidas, LGPD. |
| Certificados da ONG | `lib/certificadosOng.dart` | ONG | Resumo e lista de voluntários certificados. |
| Planos (ONG) | `lib/planosOng.dart` | ONG | Gratuito × Premium; cancelar. |
| Checkout (ONG) | `lib/checkoutPremiumOng.dart` | ONG | Pagamento simulado. |
| Chat (lista) | `lib/chat.dart` | Usuário, ONG | Conversas com busca e não lidas. |
| Conversa | `lib/conversaChat.dart` | Usuário, ONG | Mensagens em tempo real; limpar conversa. |
| Solicitações/Notificações | `lib/notificacoes.dart` | Usuário, ONG | Solicitações recebidas; aceitar/recusar; mensagem. |
| Quem somos | `lib/quem_somos.dart` | Usuário, ONG | Texto e fundadores. |

Serviços e componentes: `lib/services/api_service.dart`, `auth_service.dart`, `chat_socket_service.dart`, `chat_sessao_service.dart`, `solicitacao_sessao_service.dart`, `notificacao_local_service.dart`, `push_service.dart`; `lib/models/conversa.dart`, `mensagem.dart`; `lib/widgets/avatar_perfil.dart`, `chat_badge_icon.dart`, `notificacao_badge_icon.dart`, `moderacao_dialogs.dart`; `lib/utils/input_formatters.dart`; `lib/firebase_options.dart` (gerado).

### 5.3 Desktop
| Tela | Arquivo | Perfil | O que faz |
|---|---|---|---|
| Login | `electron/src/views/index.html` | Adm. Sistema | Login do administrador. |
| Início (dashboard) | `electron/src/views/inicio.html` | Adm. Sistema | Totais e gráfico. |
| Usuários | `electron/src/views/usuarios.html` | Adm. Sistema | Listar, buscar, editar, cadastrar usuários. |
| ONGs | `electron/src/views/ongs.html` | Adm. Sistema | Listar, buscar, editar, cadastrar ONGs. |
| Serviços | `electron/src/views/servicos.html` | Adm. Sistema | Listar, buscar, editar serviços de usuários. |
| Solicitações | `electron/src/views/solicitacoes.html` | Adm. Sistema | Listar, buscar, editar solicitações entre usuários. |
| Revisão | `electron/src/views/revisao.html` | Adm. Sistema | Fila de moderação (aprovar/rejeitar). |
| Premium | `electron/src/views/premium.html` | Adm. Sistema | Contas Premium, receita estimada, remover Premium. |
| Perfil do admin | `electron/src/views/perfil.html` | Adm. Sistema | Mudar login/senha, adicionar administrador. |

Arquivos de suporte: `electron/main.js` (janelas, token, `fetch` à API, IPC), `electron/preload.js` (`window.api`), `electron/src/views/tema.js` (modo escuro), `electron/src/views/style.css`. `electron/renderer.js` e `electron/teste.js` estão comentados/de teste e não fazem parte do fluxo.

---

## 6. Endpoints da API

Autenticação: **Admin** = exige `Authorization: Bearer <token>` (middleware `autenticarAdm`); **Pública** = sem autenticação; **Senha** = identifica a conta por e-mail + senha no corpo. Limites por IP: **L-login** (30/15 min), **L-email** (10/15 min), **L-código** (30/15 min).

| Método | Rota | Autenticação | Descrição | Usado por (Web/Mobile/Desktop) |
|---|---|---|---|---|
| GET | `/health` | Pública | Resposta "API está ativada!" (auto-ping). | API |
| GET | `/uploads/fotos/:nome` | Pública | Foto de perfil (do banco; cai no arquivo em disco). | W, M |
| GET | `/uploads/servicos/:nome` | Pública | Imagem de serviço (do banco; cai no disco). | W, M, D |
| GET | `/uploads/*` (static) | Pública | Arquivos de `uploads/`. | W, M |
| GET | `/email/*` (static) | Pública | Logo usado nos e-mails. | E-mails |
| POST | `/login` | Pública, L-login | Login do admin; devolve token. | D |
| POST | `/loginUsuario` | Pública, L-login | Login de usuário comum. | W, M |
| POST | `/loginOng` | Pública, L-login | Login de ONG. | W, M |
| POST | `/esqueciSenha` | Pública, L-email | Envia código de recuperação. | W, M |
| POST | `/verificarCodigo` | Pública, L-código | Confere código (sem consumir). | W, M |
| POST | `/redefinirSenha` | Pública, L-código | Troca a senha com o código. | W, M |
| POST | `/confirmarEmail` | Pública, L-código | Confirma o e-mail do cadastro. | W, M |
| POST | `/reenviarConfirmacao` | Pública, L-email | Reenvia código de confirmação. | W, M |
| POST | `/minhaConta/dados` | Senha, L-login | Exporta dados (JSON ou por e-mail). | W, M |
| POST | `/minhaConta/excluir` | Senha, L-login | Anonimiza a conta. | W, M |
| GET | `/usuarios` | Admin | Lista todos os usuários. | D |
| POST | `/usuarios` | Pública, L-email | Cadastra usuário e envia código. | W, M, D |
| GET | `/usuarios/:cpf` | Pública | Dados do usuário (sem senha/foto). | W, M |
| PUT | `/usuarios/:cpf` | Admin | Altera ativo, pontos e horas. | D |
| PUT | `/usuarios/:cpf/perfil` | Pública | Atualiza nome, e-mail, telefone, cidade. | W, M |
| GET | `/usuarios/:cpf/estatisticas` | Pública | Horas e trabalhos concluídos. | W |
| GET | `/usuarios/:cpf/dashboard` | Pública | Horas, trabalhos, pontos e plano. | M |
| GET | `/usuarios/:cpf/movimentacao` | Pública | Pontos recebidos/gastos no mês. | W |
| PUT | `/usuarios/:cpf/premium` | Pública | Ativa/cancela Premium (0/1). | W, M |
| GET | `/ongs` | Admin | Lista todas as ONGs. | D |
| POST | `/ongs` | Pública, L-email | Cadastra ONG e envia código. | W, M, D |
| GET | `/ongs/:cnpj` | Pública | Dados da ONG + pontos + atividades ativas; aplica bônus mensal. | W, M |
| GET | `/ongs/:cnpj/voluntarios-realizados` | Pública | Total de voluntários distintos (rota registrada **duas vezes**). | W |
| PUT | `/ongs/:cnpj` | Admin | Altera ativo, responsável e foco. | D |
| PUT | `/ongs/:cnpj/perfil` | Pública | Atualiza nome, e-mail, telefone, cidade. | W, M |
| GET | `/ongs/:cnpj/movimentacao` | Pública | Gastos do mês e bônus recebido. | W |
| PUT | `/ongs/:cnpj/premium` | Pública | Ativa/cancela Premium da ONG. | W, M |
| GET | `/servicos` | Admin | Lista serviços de usuários. | D |
| POST | `/servicos` | Pública | Cadastra serviço de usuário (limite + moderação). | W, M |
| GET | `/servicos/:id` | Pública | Um serviço de usuário (edição). | W |
| PUT | `/servicos/:id` | Pública | Atualiza serviço de usuário (moderação se mudou conteúdo). | W, M |
| PATCH | `/servicos/:id/status` | Pública | Ativa/desativa serviço de usuário. | W, M |
| GET | `/servicos/usuario/:cpf` | Pública | Serviços ativos de um usuário. | W, M |
| POST | `/servicos/ong` | Pública | Cadastra atividade de ONG (limite + moderação). | W, M |
| GET | `/servicos/ong/:cnpj` | Pública | Atividades ativas de uma ONG. | W, M |
| GET | `/servicos/ong/detalhe/:id` | Pública | Uma atividade (edição). | W |
| PUT | `/servicos/ong/:id` | Pública | Atualiza atividade. | W, M |
| PATCH | `/servicos/ong/:id/status` | Pública | Ativa/desativa atividade. | W, M |
| GET | `/servicos-usuario` | Pública | Vitrine de serviços de usuários aprovados. | W, M |
| GET | `/servicos-ong` | Pública | Vitrine de atividades de ONGs aprovadas. | W, M |
| GET | `/servicos-destaque` | Pública | Serviços/atividades de contas Premium. | W, M |
| GET | `/servicos-perto/:cidade` | Pública | Destaques Premium da mesma cidade. | W |
| GET | `/solicitacoes` | Admin | Lista solicitações entre usuários. | D |
| POST | `/solicitacoes` | Pública | Cria solicitação de serviço de usuário (socket + push). | W, M |
| PUT | `/solicitacoes/:cod` | Pública | Aceita/recusa (socket + push ao solicitante). | W, M |
| GET | `/solicitacoes/prestador/:cpf` | Pública | Solicitações recebidas. | W, M |
| GET | `/solicitacoes/usuario/:cpf` | Pública | Solicitações feitas. | W, M |
| GET | `/solicitacoes/confirmar/:cpf` | Pública | Aceitas aguardando confirmação. | W, M |
| PUT | `/solicitacoes/:cod/confirmar` | Pública | Confirma realização e transfere pontos. | W, M |
| POST | `/solicitacoes/:cod/avaliar` | Pública | Avalia o serviço (1–5). | W, M |
| PUT | `/solicitacoes/:cod/lida` | Pública | Marca solicitação como lida. | M |
| GET | `/solicitacoes/naolidas/:cpf` | Pública | Total de não lidas (badge). | W, M |
| POST | `/solicitacoes-ong` | Pública | Cria interesse em atividade de ONG (socket + push). | W, M |
| PUT | `/solicitacoes-ong/:cod` | Pública | ONG aceita/recusa (socket + push). | W, M |
| GET | `/solicitacoes-ong/prestador/:cnpj` | Pública | Interesses recebidos pela ONG. | W, M |
| GET | `/solicitacoes-ong/usuario/:cpf` | Pública | Participações do usuário em ONGs. | W |
| GET | `/solicitacoes-ong/confirmar/:cnpj` | Pública | Aceitas aguardando confirmação da ONG. | W |
| PUT | `/solicitacoes-ong/:cod/confirmar` | Pública | ONG confirma e transfere pontos. | W |
| POST | `/solicitacoes-ong/:cod/avaliar` | Pública | ONG avalia (grava na média da atividade). | W |
| GET | `/solicitacoes-ong/recebidos/:cnpj` | Pública | Atividades realizadas (histórico da ONG). | W |
| GET | `/solicitacoes-ong/naolidas/:cnpj` | Pública | Não lidas da ONG (badge). | W, M |
| PUT | `/solicitacoes-ong/:cod/lida` | Pública | Marca como lida. | M |
| GET | `/certificados/:cpf` | Pública | Resumo e lista de certificados do usuário. | W, M |
| GET | `/certificados/:cpf/:codSolicitacao/pdf` | Pública | Gera o PDF (Puppeteer + QR). | W, M |
| GET | `/certificados/ong/:cnpj` | Pública | Certificados emitidos pela ONG. | W, M |
| GET | `/verificar/:codigo` | Pública | Verifica autenticidade do certificado. | W |
| POST | `/perfil/foto` | Pública | Envia foto do usuário (multer). | W, M |
| GET | `/perfil/foto/:cpf` | Pública | Caminho da foto do usuário. | W, M |
| POST | `/perfil/foto/ong` | Pública | Envia foto da ONG. | W, M |
| GET | `/perfil/foto/ong/:cnpj` | Pública | Caminho da foto da ONG. | W, M |
| POST | `/conversas` | Pública | Busca ou cria conversa entre duas contas. | W, M |
| GET | `/conversas/:tipo/:id` | Pública | Conversas da conta com não lidas e prévia. | W, M |
| GET | `/conversas/:conversaId/mensagens` | Pública | Mensagens (respeita "limpo em"). | W, M |
| POST | `/conversas/:conversaId/mensagens` | Pública | Envia mensagem por HTTP (alternativa ao socket). | — (não usada) |
| PATCH | `/conversas/:conversaId/lida` | Pública | Marca conversa como lida por HTTP. | — (não usada; usa socket) |
| PUT | `/conversas/:conversaId/limpar` | Pública | Limpa a conversa para uma conta. | W, M |
| POST | `/notificacoes/token` | Pública | Registra token FCM do aparelho. | M |
| POST | `/contato` | Pública, L-email | Envia mensagem de contato por e-mail. | W |
| GET | `/premium` | Admin | Registros de pagamento Premium (tabelas `*Premium`). | — (exposta no preload, sem tela) |
| GET | `/premium/contas` | Admin | Contas com `premium = 1`. | D |
| GET | `/stats/premium-total` | Admin | Total de registros de pagamento. | — (sem tela) |
| GET | `/stats/atrasadas` | Admin | Pagamentos com `statusPag = 0`. | — (sem tela) |
| GET | `/stats/receita` | Admin | Soma de `qtdPag` × 25. | — (sem tela) |
| GET | `/stats/:tipo` | Admin | `usuarios`, `ongs`, `servicos`, `horas`, `usuarios-inativos`, `pontos`, `ongs-inativas`, `premium`, `servicos-cadastrados`, `aceitas`, `pendentes`, `recusadas`, `media-notas`. | D |
| PUT | `/adm/login` | Admin | Altera o login do admin; devolve novo token. | D |
| PUT | `/adm/senha` | Admin | Altera a senha do admin. | D |
| POST | `/adm/cadastrar` | Admin | Cadastra outro admin. | D |
| PUT | `/adm/servicos/:cod` | Admin | Edita serviço (ativo, horas, foco, nota). | D |
| PUT | `/adm/solicitacoes/:cod` | Admin | Edita solicitação (status e pontos). | D |
| PUT | `/adm/usuarios/:cpf/premium` | Admin | Remove Premium do usuário. | D |
| PUT | `/adm/ongs/:cnpj/premium` | Admin | Remove Premium da ONG. | D |
| GET | `/moderacao/servicos` | Admin | Fila de serviços em REVISAO. | D |
| PUT | `/moderacao/servicos/:tipo/:id` | Admin | Aprovar/rejeitar serviço. | D |

**Eventos Socket.IO:** `identificar` (cliente → servidor; entra na sala `tipo:id`), `mensagem:enviar` (cliente → servidor), `mensagem:nova` (servidor → destinatário), `mensagem:enviada` (servidor → remetente), `conversa:lida` (bidirecional), `solicitacao:nova` e `solicitacao:atualizada` (servidor → cliente).

**Middleware de erro global:** responde sempre JSON — "A imagem deve ter no máximo 3 MB.", "Não foi possível processar o arquivo enviado.", "Conteúdo grande demais.", "Requisição inválida.", "Erro ao processar a requisição.".

---

## 7. Banco de dados

> Não há script de criação (DDL) das tabelas principais no repositório. As colunas abaixo foram inferidas das consultas em `mutuo-api/db.js`; os **tipos** só são informados onde existe DDL no código (migrations ou `inicializarTabelas`). Chaves estrangeiras marcadas como "(inferida)" vêm dos `JOIN`s, não de `FOREIGN KEY` declarada.

### Mutuo_Adm
- Colunas: `login` (identificador), `senha` (hash bcrypt).
- Para que serve: administradores do painel Desktop.

### Mutuo_Usuario
- PK: `cpf`.
- Colunas: `nome`, `email`, `senha` (bcrypt), `telefone`, `cidade`, `bairro`, `cep`, `dataNasc`, `estado`, `endereco`, `cadastro` (data), `pontos` (inicia em 20), `horasVoluntarias`, `ativo` (0/1), `premium` (0/1), `foto_perfil` (nome do arquivo), `foto_perfil_dados` LONGBLOB NULL, `foto_perfil_tipo` VARCHAR(100) NULL, `email_verificado` TINYINT(1) NOT NULL DEFAULT 1, `excluido_em` DATETIME NULL.
- Para que serve: contas de usuários comuns.

### Mutuo_ONG
- PK: `cnpj`.
- Colunas: `nomeOng`, `nomeResponsavel`, `email`, `senha` (bcrypt), `telefone`, `cidade`, `bairro`, `endereco`, `estado`, `foco` (minúsculo), `descricao`, `foto_perfil`, `foto_perfil_dados` LONGBLOB NULL, `foto_perfil_tipo` VARCHAR(100) NULL, `cadastro`, `pontos` (inicia em 0), `premium`, `ativo`, `ultimoBonusMensal` (data), `email_verificado` TINYINT(1) NOT NULL DEFAULT 1, `excluido_em` DATETIME NULL.
- Para que serve: contas de ONGs.

### Mutuo_Servico
- PK: `cod`. FK (inferida): `idUsuario` → `Mutuo_Usuario.cpf`.
- Colunas: `nome`, `descricao`, `foco`, `qtdHoras`, `imagem`, `imagem_dados` LONGBLOB NULL, `imagem_tipo` VARCHAR(100) NULL, `pontos`, `ativo`, `nota`, `avaliacoes`, `moderacao_status` ENUM('APROVADO','REVISAO','BLOQUEADO') NOT NULL DEFAULT 'APROVADO', `moderacao_categoria` VARCHAR(50) NULL, `moderacao_motivo` TEXT NULL, `moderacao_confianca` DECIMAL(4,3) NULL, `moderacao_data` DATETIME NULL, `moderacao_revisado_por` VARCHAR(100) NULL, `moderacao_data_revisao` DATETIME NULL. Referência a uma coluna `avaliacao` apenas em `alterServico` (admin).
- Para que serve: serviços oferecidos por usuários.

### Mutuo_ServicoOng
- PK: `id`. FK (inferida): `cnpj` → `Mutuo_ONG.cnpj`.
- Colunas: `nomeServico`, `horas`, `descricao`, `foco`, `imagem`, `imagem_dados` LONGBLOB NULL, `imagem_tipo` VARCHAR(100) NULL, `pontos`, `ativo`, `nota` DECIMAL(2,1) NULL, `avaliacoes` INT NOT NULL DEFAULT 0, colunas `moderacao_*` iguais às de `Mutuo_Servico`.
- Para que serve: atividades de voluntariado das ONGs.

### Mutuo_Solicitacao
- PK: `codSolicitacao`. FKs (inferidas): `codServico` → `Mutuo_Servico.cod`; `codUsuario` → `Mutuo_Usuario.cpf` (solicitante).
- Colunas: `statusSolicitacao` ('Pendente'/'Aceita'/'Recusada'), `statusExecucao` ('Não iniciado'/'Realizada'/'Cancelado'), `dataSolicitacao`, `dataConclusao`, `pontos`, `nota`, `avaliado`, `lida`.
- Para que serve: pedidos de serviço entre usuários.

### Mutuo_SolicitacaoONG
- PK: `codSolicitacao`. FKs (inferidas): `codServico` → `Mutuo_ServicoOng.id`; `codUsuario` → `Mutuo_Usuario.cpf` (voluntário).
- Colunas: `statusSolicitacao`, `statusExecucao`, `dataSolicitacao`, `dataConclusao`, `pontos`, `codigoVerificacao` (UUID do certificado), `lida` TINYINT(1) DEFAULT 0, `avaliado` TINYINT(1) NOT NULL DEFAULT 0, `nota` TINYINT NULL.
- Para que serve: interesses/participações de voluntários em atividades de ONGs; base dos certificados.

### Mutuo_UsuarioPremium / Mutuo_ONGPremium
- Colunas: `id`, `cpf` (ou `cnpj`), `statusPag`, `qtdPag`.
- Para que serve: registros de pagamento Premium. Só são **lidas** por rotas de estatística do admin; nenhum fluxo grava nelas. O plano efetivo é a coluna `premium` de `Mutuo_Usuario`/`Mutuo_ONG`.

### Mutuo_Conversa (migration `001_chat.js`)
- `id` INT AUTO_INCREMENT PK; `tipo_participante_1` ENUM('usuario','ong'); `id_participante_1` VARCHAR(20); `tipo_participante_2` ENUM('usuario','ong'); `id_participante_2` VARCHAR(20); `criada_em` DATETIME; `ultima_mensagem_em` DATETIME; UNIQUE (`tipo_participante_1`,`id_participante_1`,`tipo_participante_2`,`id_participante_2`). Colunas `limpo_em_participante_1` e `limpo_em_participante_2` são usadas pelo código, mas **não aparecem na migration**.
- Para que serve: conversas do chat.

### Mutuo_Mensagem (migration `001_chat.js`)
- `id` INT AUTO_INCREMENT PK; `conversa_id` INT FK → `Mutuo_Conversa(id)`; `tipo_remetente` ENUM('usuario','ong'); `id_remetente` VARCHAR(20); `conteudo` TEXT; `enviada_em` DATETIME DEFAULT CURRENT_TIMESTAMP; `lida` TINYINT(1) DEFAULT 0.
- Para que serve: mensagens do chat.

### Mutuo_DispositivoToken (migration `002_push_tokens.js`)
- `id` INT AUTO_INCREMENT PK; `tipo` ENUM('usuario','ong'); `identificador` VARCHAR(20); `token_fcm` VARCHAR(255) UNIQUE; `atualizado_em` DATETIME.
- Para que serve: tokens de push FCM por aparelho.

### Mutuo_RecuperacaoSenha / Mutuo_ConfirmacaoEmail (`db.inicializarTabelas`)
- `id` INT AUTO_INCREMENT PK; `tipo` ENUM('usuario','ong'); `identificador` VARCHAR(20); `email` VARCHAR(255); `codigo_hash` VARCHAR(255); `expira_em` DATETIME; `tentativas` INT DEFAULT 0; `usado` TINYINT(1) DEFAULT 0; `criado_em` DATETIME DEFAULT CURRENT_TIMESTAMP; índice (`email`,`tipo`).
- Para que serve: códigos de 6 dígitos de recuperação de senha e de confirmação de e-mail.

### Migrations e criação automática
| Arquivo | O que faz |
|---|---|
| `migrations/001_chat.js` | Cria `Mutuo_Conversa` e `Mutuo_Mensagem`. |
| `migrations/002_push_tokens.js` | Cria `Mutuo_DispositivoToken`. |
| `migrations/003_normalizar_foco.js` | Converte `foco` para minúsculas/sem espaços em `Mutuo_ONG`, `Mutuo_Servico`, `Mutuo_ServicoOng`. |
| `migrations/004_solicitacao_ong_lida.js` | Adiciona `Mutuo_SolicitacaoONG.lida`. |
| `migrations/005_imagens_no_banco.js` | Adiciona colunas de bytes/tipo de imagem (perfil e serviços). |
| `migrations/006_avaliacao_ong.js` | Adiciona `avaliado`/`nota` em `Mutuo_SolicitacaoONG` e `nota`/`avaliacoes` em `Mutuo_ServicoOng`. |
| `migrations/2026_09_add_moderacao_servico.sql` + `aplicar-moderacao.js` | Adiciona as colunas `moderacao_*` nas duas tabelas de serviço. |
| `db.inicializarTabelas()` (ao subir a API) | Cria `Mutuo_RecuperacaoSenha`, `Mutuo_ConfirmacaoEmail` e as colunas `email_verificado` e `excluido_em`. |

**Diferenças em relação ao MER:** não há MER nem comentários no repositório que o descrevam. Pontos que provavelmente diferem de um MER antigo: tabelas de chat, push, códigos de e-mail e colunas de moderação/LGPD são novas; avaliação fica no serviço (não no usuário); o plano Premium é uma coluna `premium` nas tabelas de conta, e as tabelas `*Premium` não são alimentadas.

---

## 8. Diferenças em relação à documentação atual

### 8.0 Status dos requisitos documentados (2.5)
| Requisito | Status | Onde |
|---|---|---|
| 2.5.1 Cadastrar ONG | ✅ | 4.2 |
| 2.5.2 Editar ONG | ✅ | 4.11 |
| 2.5.3 Excluir ONG | ✅ (anonimização/inativação) | 4.13, 4.52 |
| 2.5.4 Cadastrar Usuário | ✅ | 4.1 |
| 2.5.5 Editar Usuário | ✅ | 4.10 |
| 2.5.6 Excluir Usuário | ✅ (anonimização/inativação) | 4.13, 4.51 |
| 2.5.7 Cadastrar Serviço | ✅ | 4.15, 4.16 |
| 2.5.8 Editar Serviço | ✅ | 4.17 |
| 2.5.9 Excluir Serviço | ✅ (exclusão lógica) | 4.18 |
| 2.5.10 Consultar Usuário ou Serviço | 🟡 (serviço sim; usuário só no admin) | 4.22, 4.25 |
| 2.5.11 Consultar ONG | ✅ (perfil público só na Web, com botão sem ação) | 4.23, 4.24 |
| 2.5.12 Login | ✅ | 4.4, 4.5 |
| 2.5.13 Logout | ✅ | 4.6 |
| 2.5.14 Tela de Apresentação | 🟠 | 4.42 |
| 2.5.15 Tela Inicial | ✅ | 4.43 |
| 2.5.16 Tela de Perfil | ✅ | 4.9 |
| 2.5.17 Tela de Serviços | ✅ | 4.22 |
| 2.5.18 Tela de ONGs | ✅ | 4.23 |
| 2.5.19 Chat | ✅ | 4.36 |
| 2.5.20 Tela de Solicitações | ✅ | 4.29 |
| 2.5.21 Confirmar Realização do Serviço | ✅ (ONG só na Web) | 4.32 |
| 2.5.22 Histórico de Serviços | ✅ | 4.35 |
| 2.5.23 Confirmação de Pontos | ✅ | 4.33 |
| 2.5.24 Avaliação de Usuários | 🟡 | 4.34 |
| 2.5.25 Demonstrar Interesse em ONG | ✅ | 4.28 |
| 2.5.26 Tela de Interesse (ONG) | ✅ | 4.30 |
| 2.5.27 Gerar Certificado | ✅ | 4.39 |
| 2.5.28 Tela de Propaganda do Premium | ✅ | 4.46 |
| 2.5.29 Tela de Upgrade | 🟠 (pagamento simulado) | 4.47 |
| 2.5.30 Benefícios Premium | 🟡 | 4.49 |

Casos de uso (2.9): Cadastrar Usuário ✅ · Login ✅ · Cadastrar ONG ✅ · Editar Dados do Usuário ✅ · Cadastrar Serviço ✅ · Solicitar Serviço ✅ · **Cancelar Solicitação ❌** · Enviar Mensagem (Chat) ✅ · Avaliar Usuário/Serviço 🟡 · Validar Serviço ✅ · Gerar Certificado ✅ · Notificação ✅ · Contratar Plano Premium 🟠.

### 8.1 Funcionalidades documentadas mas não encontradas no código
- **Cancelar Solicitação** (caso de uso 2.9): o solicitante não consegue cancelar um pedido; não há rota nem botão (4.31).
- **Avaliação de usuários** (2.5.24), no sentido literal: não existe nota para o usuário; avalia-se o serviço (4.34).
- **Consulta de usuários** por usuários/ONGs (parte de 2.5.10): só o administrador busca usuários (4.25).
- **Pagamento real** do Premium (2.5.29 / 2.9): o checkout é simulado (4.47).

### 8.2 Funcionalidades novas (existem no código e não estão na documentação)
1. Confirmação de e-mail no cadastro por código (4.3).
2. Sessão persistente no app (4.7).
3. Esqueci minha senha com código por e-mail via Brevo (4.8).
4. Upload de foto de perfil, com imagem guardada no banco (4.12).
5. Exportar meus dados — LGPD (4.14).
6. Limite de serviços por plano (3/8 usuário; 5/10 ONG) (4.19).
7. Moderação automática de serviços por IA (Gemini, 3 camadas) (4.20).
8. Revisão manual de serviços pelo admin (4.21).
9. Vagas em destaque e "Perto de você" (por cidade cadastrada, não geolocalização) (4.26).
10. Formulário de Contato com envio por e-mail (4.38).
11. Certificados emitidos pela ONG (4.40).
12. Verificação pública de certificado por código e QR code (4.41).
13. Como usar a plataforma (4.44).
14. Quem somos (4.45).
15. Cancelar Premium (4.48).
16. Dashboard administrativo com gráfico (4.50).
17. Gerenciar Usuários (4.51).
18. Gerenciar ONGs (4.52).
19. Gerenciar Serviços (4.53).
20. Gerenciar Solicitações (4.54).
21. Gerenciar contas Premium (4.55).
22. Perfil do administrador: mudar login/senha e cadastrar admin (4.56).
23. Modo escuro no Desktop (4.57).
24. Preenchimento de endereço por CEP (ViaCEP) (4.58).

Também ligados a funcionalidades documentadas, mas não descritos nela: notificações push (Firebase) e notificações locais no app; badges de não lidas; bônus mensal de 500 pontos para ONGs; transferência de pontos em transação; movimentação mensal de pontos; limpar conversa só para um lado; exclusão de conta por anonimização.

### 8.3 Funcionalidades documentadas com comportamento diferente do código
- **Excluir Usuário / Excluir ONG (2.5.3, 2.5.6):** não há exclusão física. A própria conta é **anonimizada** (dados pessoais apagados, `ativo = 0`, CPF/CNPJ mantido, sem possibilidade de recadastro), e o admin pode só **inativar**.
- **Excluir Serviço (2.5.9):** exclusão lógica (`ativo = 0`).
- **Cadastrar Serviço (2.5.7):** agora passa por moderação por IA e pode ficar "Em análise" ou ser bloqueado; há limite de serviços por plano.
- **Login (2.5.12):** contas com e-mail não confirmado não entram; o app tenta usuário e depois ONG com o mesmo formulário; a Web pede para escolher o tipo. O login do admin é separado (Desktop, com token).
- **Logout (2.5.13):** Web e app voltam para a tela de **login** (não para a apresentação).
- **Avaliação (2.5.24):** avalia-se o **serviço**; a ONG "avalia o voluntário", mas a nota vai para a média da atividade da própria ONG; só é oferecida logo após confirmar.
- **Confirmação de Pontos (2.5.23):** os pontos são transferidos automaticamente na confirmação de realização (não há etapa separada); usuário começa com 20; ONG recebe +500/mês se tiver até 1000; o saldo pode ficar negativo; quem cadastra o serviço escolhe 10–50 pontos (a página "Como usar" diz que os pontos são definidos pela equipe).
- **Confirmar Realização (2.5.21):** quem confirma é quem **recebeu** o serviço (solicitante) ou a ONG; no app, a ONG não confirma.
- **Gerar Certificado (2.5.27):** só para atividades de **ONG** concluídas (trocas entre usuários não geram certificado); inclui QR code e código de verificação.
- **Tela de ONGs (2.5.18):** lista **atividades** de ONGs, não um catálogo de ONGs; o perfil da ONG é acessado pelo nome dela (só Web).
- **Tela de Apresentação (2.5.14):** números e depoimentos fixos.
- **Tela de Upgrade / Contratar Premium (2.5.29):** pagamento simulado; ativa o plano direto pela coluna `premium`.
- **Benefícios Premium (2.5.30):** só limite maior de serviços e destaque nas seções da home são reais; os demais benefícios anunciados não existem, e os textos variam entre Web e Mobile.
- **Tela Inicial e Perfil (2.5.15, 2.5.16):** contêm indicadores fixos ("5.0" de avaliação; "3" no atalho de notificações da ONG na Web).
- **Diferenças entre plataformas:** senha mínima de 8 (Web) × 6 (app) no cadastro; o app não tem contato, como usar, perfil público de ONG, "Perto de você", "Meus pedidos", confirmação/avaliação pela ONG; o botão "Participar" das vagas em destaque do app é simulado; o chip "Filtros" do app não faz nada; editar o perfil da ONG pelo app apaga a cidade.

---

## 9. Requisitos não funcionais identificados

**Segurança**
- Senhas de usuários, ONGs e administradores com **bcrypt** (custo 10); senhas antigas em texto puro são migradas para hash no primeiro login.
- Respostas nunca devolvem senha/hash nem os bytes da foto.
- **Administrador:** token HMAC-SHA256 (`crypto` nativo), validade de 12 h, comparação em tempo constante; guardado só no processo principal do Electron; `contextIsolation: true` e `nodeIntegration: false`.
- **Usuário/ONG: não há token nem sessão no servidor.** As rotas recebem CPF/CNPJ do cliente e não verificam o dono (incluindo leitura de mensagens do chat e o evento `identificar` do socket). Exceção: exportar/excluir conta exige e-mail + senha. (Registrado como pendente em `MELHORIAS.md`, item 1.1.)
- Limite de tentativas por IP em memória (login 30/15 min; envio de e-mail 10/15 min; códigos 30/15 min), com HTTP 429 e `Retry-After`; `trust proxy` ligado para o Render.
- Códigos de 6 dígitos com hash bcrypt, validade de 15 min, 5 tentativas, intervalo de 60 s e respostas genéricas (não revelam se o e-mail existe).
- `escaparHtml` no e-mail de contato e no template do certificado; a tela de revisão do Desktop e a verificação de certificado escapam dados antes de inserir no HTML.
- Upload restrito a JPG/PNG/WEBP até 3 MB; corpo JSON até 20 MB.
- Middleware de erro global que não expõe detalhes internos.
- CORS aberto (`cors()` sem lista de origens); Socket.IO com `origin: '*'`.
- Observação: `mutuo-api/.env` e `mutuo-api/firebase-service-account.json` estão versionados no Git (decisão comentada no `.gitignore`); a `GEMINI_API_KEY` fica em `.env.local`, fora do Git. Os nomes dos arquivos de foto contêm CPF/CNPJ.

**Privacidade (LGPD)**
- Exportação dos dados da conta (download ou e-mail) e exclusão por anonimização com confirmação por senha.

**Disponibilidade e desempenho**
- API hospedada no Render (plano gratuito); auto-ping em `/health` a cada 10 min.
- Imagens gravadas no banco (LONGBLOB) porque o disco do Render não é persistente.
- Web e Mobile repetem a chamada uma vez quando a API está em cold start ("Servidor iniciando, tente novamente em alguns segundos").
- Pool de conexões MySQL (10) com fuso `-03:00`.
- Transações com `FOR UPDATE` na confirmação de serviços e nas avaliações.
- Busca e filtros das telas de Serviços/ONGs feitos no navegador sobre a lista completa.
- Certificado em PDF gerado sob demanda com Puppeteer (um Chrome por pedido).
- Moderação por IA com timeout de 20 s, nova tentativa e modelo reserva.

**Tempo real e notificações**
- Socket.IO para chat, badges e solicitações; push FCM (Android) com `priority: 'high'`; limpeza automática de tokens inválidos.

**Usabilidade e interface**
- Web responsiva: navbar com menu hambúrguer/drawer gerado por `navbarUsuarioResponsiva.js`/`navbarOngResponsiva.js`; páginas internas protegidas (redirecionam ao login sem sessão, inclusive ao voltar pelo histórico).
- Máscaras de CPF, CNPJ, telefone, CEP e cartão (Web e Mobile).
- App em português do Brasil (`Locale('pt','BR')`), fonte Quicksand.
- Modo escuro só no Desktop.
- Mensagens de feedback com SweetAlert2 (Web/Desktop) e SnackBar (Mobile); estados de carregamento e listas vazias.

**Qualidade / manutenção**
- Não há testes automatizados (`mobile/mutuo/test/widget_test.dart` é o exemplo padrão do Flutter; `moderation/testar-moderacao.js` é um teste manual da moderação).
- Migrations manuais em `mutuo-api/migrations/` + criação automática de tabelas/colunas ao subir a API.
- Bootstrap em três versões diferentes na Web; pastas com acento (`usuárioComum`, `usuárioOng`).
