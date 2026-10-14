const express = require('express');
const cors = require('cors');
const path = require('path');
const multer = require('multer');
const fs = require('fs');
const http = require('http');
const { Server } = require('socket.io');
const { initializeApp: initializeFirebaseApp, cert } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const db = require('./db');
const { avaliarServico } = require('./moderation/moderationService');
const crypto = require('crypto');

// Push é acessório: se a credencial não estiver presente (ex: ambiente de
// desenvolvimento sem o arquivo), o chat via socket continua funcionando normalmente.
let mensageria = null;
try {
  const credenciais = require('./firebase-service-account.json');
  const firebaseApp = initializeFirebaseApp({ credential: cert(credenciais) });
  mensageria = getMessaging(firebaseApp);
} catch (err) {
  console.warn('Push via Firebase desativado (firebase-service-account.json ausente ou inválido):', err.message);
}

// Envia push para os tokens de uma conta e limpa os tokens que o Firebase
// reportou como inválidos/desregistrados.
async function enviarPush(tipo, id, { titulo, corpo, dados }) {
  if (!mensageria) return;

  const tokens = await db.getTokensDaConta(tipo, id);
  if (!tokens.length || tokens.error) return;

  try {
    const resposta = await mensageria.sendEachForMulticast({
      tokens,
      notification: { title: titulo, body: corpo },
      data: dados || {},
      android: {
        priority: 'high' // garante entrega imediata mesmo com o dispositivo
                          // em Doze/economia de energia ou com o app encerrado.
      }
    });

    const tokensInvalidos = resposta.responses
      .map((r, i) => (r.success ? null : tokens[i]))
      .filter(Boolean);
    await db.removerTokensInvalidos(tokensInvalidos);
  } catch (err) {
    console.error('Erro ao enviar push:', err.message);
  }
}

// Envio de e-mail transacional via Brevo (API HTTP — o Render gratuito
// bloqueia SMTP). Lança erro se falhar, para a rota poder avisar o usuário.
// Escapa texto vindo do cliente antes de colocar dentro de HTML
// (e-mails, template do certificado).
function escaparHtml(valor) {
  return String(valor ?? '').replace(/[&<>"']/g, c => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));
}

async function enviarEmailBrevo({ para, assunto, html, responderPara, anexos }) {
  const resposta = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': process.env.BREVO_API_KEY,
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    },
    body: JSON.stringify({
      sender: {
        name: process.env.NOME_REMETENTE || 'Mútuo',
        email: process.env.EMAIL_REMETENTE
      },
      to: [{ email: para }],
      subject: assunto,
      htmlContent: html,
      ...(responderPara ? { replyTo: { email: responderPara } } : {}),
      // anexos: [{ nome: 'arquivo.json', conteudoBase64: '...' }]
      ...(Array.isArray(anexos) && anexos.length > 0
        ? { attachment: anexos.map(a => ({ name: a.nome, content: a.conteudoBase64 })) }
        : {})
    })
  });

  if (!resposta.ok) {
    const corpo = await resposta.text();
    throw new Error(`Brevo respondeu ${resposta.status}: ${corpo}`);
  }
}

function htmlEmailCodigo(codigo, finalidade = 'recuperacao') {
  const textos = finalidade === 'confirmacao'
    ? {
        intro: 'Boas-vindas ao Mútuo! Para ativar sua conta, confirme seu e-mail com o código abaixo:',
        rodape: 'O código vale por <b>15 minutos</b>. Se você não criou uma conta no Mútuo, pode ignorar este e-mail.'
      }
    : {
        intro: 'Olá! Recebemos um pedido para redefinir a senha da sua conta.<br>Use o código abaixo:',
        rodape: 'O código vale por <b>15 minutos</b>. Se você não pediu isso, pode ignorar este e-mail — sua senha continua a mesma.'
      };
  const logoUrl = (process.env.API_URL_PUBLICA || 'https://mutuo-api.onrender.com') + '/email/logo.png';

  const digitos = codigo.split('').map(d =>
    `<td style="width:44px;height:54px;background:#f1f5f2;border-radius:10px;font-size:28px;font-weight:700;color:#3A5A40;text-align:center;font-family:Arial,sans-serif;">${d}</td>`
  ).join('<td style="width:8px;"></td>');

  return `
  <div style="background:#f4f6f4;padding:32px 0;font-family:Arial,sans-serif;">
    <table align="center" cellpadding="0" cellspacing="0" style="max-width:480px;width:100%;background:#ffffff;border-radius:16px;overflow:hidden;">
      <tr><td style="background:#ffffff;padding:24px;text-align:center;">
        <img src="${logoUrl}" alt="Mútuo" width="140" style="display:block;margin:0 auto;width:140px;max-width:60%;height:auto;border:0;color:#3A5A40;font-size:26px;font-weight:700;font-family:Arial,sans-serif;">
      </td></tr>
      <tr><td style="background:#3A5A40;height:4px;line-height:4px;font-size:0;">&nbsp;</td></tr>
      <tr><td style="padding:32px 28px 8px;color:#333;font-size:16px;line-height:1.5;">
        ${textos.intro}
      </td></tr>
      <tr><td style="padding:16px 28px;">
        <table align="center" cellpadding="0" cellspacing="0"><tr>${digitos}</tr></table>
      </td></tr>
      <tr><td style="padding:8px 28px 32px;color:#666;font-size:14px;line-height:1.5;">
        ${textos.rodape}
      </td></tr>
      <tr><td style="background:#f1f5f2;padding:16px;text-align:center;color:#888;font-size:12px;">Mútuo — Transforme o Mundo através da Troca</td></tr>
    </table>
  </div>`;
}

// ── Limite de tentativas por IP (sem dependência) ──
// Guarda em memória: reinício da API zera as contagens, o que é aceitável.
// Os limites são generosos porque em laboratório várias pessoas saem pelo mesmo IP.
function criarLimitador({ max, janelaMs }) {
  const registros = new Map(); // ip → { contagem, inicio }

  // Limpa entradas vencidas para o Map não crescer sem limite.
  setInterval(() => {
    const agora = Date.now();
    for (const [chave, r] of registros) {
      if (agora - r.inicio > janelaMs) registros.delete(chave);
    }
  }, janelaMs).unref();

  return (req, res, next) => {
    const chave = req.ip || 'desconhecido';
    const agora = Date.now();
    let r = registros.get(chave);
    if (!r || agora - r.inicio > janelaMs) {
      r = { contagem: 0, inicio: agora };
      registros.set(chave, r);
    }
    r.contagem++;

    if (r.contagem > max) {
      const segundos = Math.ceil((r.inicio + janelaMs - agora) / 1000);
      const minutos = Math.max(1, Math.ceil(segundos / 60));
      res.set('Retry-After', String(segundos));
      return res.status(429).json({
        sucesso: false,
        mensagem: `Muitas tentativas. Tente novamente em ${minutos} minuto(s).`,
        erro: `Muitas tentativas. Tente novamente em ${minutos} minuto(s).`
      });
    }
    next();
  };
}

const QUINZE_MIN = 15 * 60 * 1000;
// O app Flutter tenta /loginUsuario e depois /loginOng: cada login conta 2.
const limiteLogin = criarLimitador({ max: 30, janelaMs: QUINZE_MIN });
// Rotas que disparam e-mail pelo Brevo (custo e risco de spam).
const limiteEnvioEmail = criarLimitador({ max: 10, janelaMs: QUINZE_MIN });
// Rotas que conferem códigos de 6 dígitos.
const limiteCodigo = criarLimitador({ max: 30, janelaMs: QUINZE_MIN });

require('dotenv').config();

const app = express();
// Render fica atrás de proxy: sem isso, req.ip seria sempre o IP do proxy.
app.set('trust proxy', 1);
app.use(cors());
app.use(express.json({ limit: '20mb' }));
app.use(express.urlencoded({ extended: true, limit: '20mb' }));

// Serve as imagens a partir do banco (persistente) quando disponível — no
// Render (plano gratuito, sem disco persistente) o arquivo em uploads/ some
// a cada reinício, mas os bytes salvos em imagem_dados/foto_perfil_dados
// continuam lá. Se não achar no banco, cai pro arquivo em disco (uploads/
// antigos, ou ambiente local) via express.static logo abaixo.
app.get('/uploads/fotos/:nome', async (req, res, next) => {
  try {
    const imagem = await db.buscarImagemPerfilPorNome(req.params.nome);
    if (!imagem) return next();
    res.set('Content-Type', imagem.tipo || 'image/jpeg');
    res.send(imagem.dados);
  } catch (err) {
    next();
  }
});

app.get('/uploads/servicos/:nome', async (req, res, next) => {
  try {
    const imagem = await db.buscarImagemServicoPorNome(req.params.nome);
    if (!imagem) return next();
    res.set('Content-Type', imagem.tipo || 'image/jpeg');
    res.send(imagem.dados);
  } catch (err) {
    next();
  }
});

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/email', express.static(path.join(__dirname, 'public', 'email')));

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

// Dada uma conversa e a conta que está agindo nela, retorna { tipo, id } da outra conta.
async function buscarOutroParticipante(conversaId, tipo, id) {
  const conversa = await db.getConversaPorId(conversaId);
  if (!conversa || conversa.error) return null;
  const souParticipante1 = conversa.tipo_participante_1 === tipo && String(conversa.id_participante_1) === String(id);
  return souParticipante1
    ? { tipo: conversa.tipo_participante_2, id: conversa.id_participante_2 }
    : { tipo: conversa.tipo_participante_1, id: conversa.id_participante_1 };
}

io.on('connection', (socket) => {
  socket.on('identificar', ({ tipo, id } = {}) => {
    if (!tipo || !id) return;
    socket.join(`${tipo}:${id}`);
  });

  socket.on('mensagem:enviar', async ({ conversaId, tipo, id, conteudo } = {}) => {
    try {
      const mensagem = await db.criarMensagem(conversaId, tipo, id, conteudo);
      if (mensagem.error) return;

      const destino = await buscarOutroParticipante(conversaId, tipo, id);
      if (destino) {
        io.to(`${destino.tipo}:${destino.id}`).emit('mensagem:nova', mensagem);

        const remetente = tipo === 'usuario'
          ? await db.getUsuarioPorCpf(id)
          : await db.getOngPorCnpj(id);
        const nomeRemetente = remetente?.nome || remetente?.nomeOng || 'Nova mensagem';

        enviarPush(destino.tipo, destino.id, {
          titulo: nomeRemetente,
          corpo: conteudo,
          dados: { conversaId: String(conversaId) }
        });
      }

      socket.emit('mensagem:enviada', mensagem);
    } catch (err) {
      console.error('Erro no evento mensagem:enviar:', err.message);
    }
  });

  socket.on('conversa:lida', async ({ conversaId, tipo, id } = {}) => {
    try {
      const destino = await buscarOutroParticipante(conversaId, tipo, id);
      await db.marcarConversaComoLida(conversaId, tipo, id);
      if (destino) io.to(`${destino.tipo}:${destino.id}`).emit('conversa:lida', conversaId);
    } catch (err) {
      console.error('Erro no evento conversa:lida:', err.message);
    }
  });
});

app.patch('/servicos/:id/status', async (req, res) => {
  try {
    const { ativo } = req.body || {};

    if (ativo === undefined) {
      return res.status(400).json({ sucesso: false, erro: 'Campo "ativo" não informado.' });
    }

    await db.atualizarStatusServico(req.params.id, ativo);
    res.json({ sucesso: true });
  } catch (e) {
    res.status(500).json({ sucesso: false, erro: e.message });
  }
});

// Garante que a pasta existe
const pastaFotos = path.join(__dirname, 'uploads', 'fotos');
if (!fs.existsSync(pastaFotos)) {
  fs.mkdirSync(pastaFotos, { recursive: true });
  console.log('Pasta criada:', pastaFotos);
}

// Configuração do multer
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, path.join(__dirname, 'uploads', 'fotos'));
  },
  filename: (req, file, cb) => {
    const idBruto = req.body?.cnpj || req.body?.cpf || 'sem-id';
    const id = idBruto.replace(/\D/g, '');
    const ext = path.extname(file.originalname);
    cb(null, `${id}-${Date.now()}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 3 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const tipos = ['image/jpeg', 'image/png', 'image/webp'];
    if (tipos.includes(file.mimetype)) cb(null, true);
    else {
      const erro = new Error('Apenas imagens JPG, PNG ou WEBP são aceitas.');
      erro.status = 400;
      erro.expor = true; // mensagem segura para mostrar ao usuário
      cb(erro);
    }
  }
});

// ── Upload de imagem para Serviços de ONG (pasta separada) ──
const pastaServicos = path.join(__dirname, 'uploads', 'servicos');
if (!fs.existsSync(pastaServicos)) {
  fs.mkdirSync(pastaServicos, { recursive: true });
  console.log('Pasta criada:', pastaServicos);
}

const storageServico = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, pastaServicos);
  },
  filename: (req, file, cb) => {
    const idBruto = req.body?.cnpj || req.body?.cpf || 'sem-id';
    const id = idBruto.replace(/\D/g, ''); // deixa só os números
    const ext = path.extname(file.originalname);
    cb(null, `${id}-${Date.now()}${ext}`);
  }
});

const uploadServico = multer({
  storage: storageServico,
  limits: { fileSize: 3 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const tipos = ['image/jpeg', 'image/png', 'image/webp'];
    if (tipos.includes(file.mimetype)) cb(null, true);
    else {
      const erro = new Error('Apenas imagens JPG, PNG ou WEBP são aceitas.');
      erro.status = 400;
      erro.expor = true; // mensagem segura para mostrar ao usuário
      cb(erro);
    }
  }
});

// Rotas de checagem
app.get('/health', (req, res) => res.status(200).send('API está ativada!'));

const https = require('https');

// Altere para a sua URL real do Render
const API_URL = 'https://mutuo-api.onrender.com/health';

// Dispara um ping a cada 10 minutos (600.000 milissegundos)
setInterval(() => {
  https.get(API_URL, (res) => {
    console.log(`Auto-ping realizado. Status: ${res.statusCode}`);
  }).on('error', (err) => {
    console.error('Erro no auto-ping:', err.message);
  });
}, 600000);



// ── Token do administrador (painel Electron) ──
// Token HMAC com o crypto nativo: base64url(payload).base64url(assinatura).
// Sem ADMIN_TOKEN_SECRET no .env, usa um segredo aleatório, e os tokens
// deixam de valer sempre que a API reinicia (o admin só precisa logar de novo).
const SEGREDO_TOKEN_ADM = process.env.ADMIN_TOKEN_SECRET || crypto.randomBytes(32).toString('hex');
if (!process.env.ADMIN_TOKEN_SECRET) {
  console.warn('ADMIN_TOKEN_SECRET não definido: tokens de admin valem só até a API reiniciar.');
}
const VALIDADE_TOKEN_ADM_MS = 12 * 60 * 60 * 1000; // 12 horas

function assinarTokenAdm(payload) {
  return crypto.createHmac('sha256', SEGREDO_TOKEN_ADM).update(payload).digest('base64url');
}

function gerarTokenAdm(login) {
  const payload = Buffer.from(JSON.stringify({ tipo: 'adm', login, exp: Date.now() + VALIDADE_TOKEN_ADM_MS })).toString('base64url');
  return `${payload}.${assinarTokenAdm(payload)}`;
}

function lerTokenAdm(token) {
  const [payload, assinatura] = String(token || '').split('.');
  if (!payload || !assinatura) return null;

  const esperada = Buffer.from(assinarTokenAdm(payload));
  const recebida = Buffer.from(assinatura);
  if (esperada.length !== recebida.length || !crypto.timingSafeEqual(esperada, recebida)) return null;

  try {
    const dados = JSON.parse(Buffer.from(payload, 'base64url').toString());
    if (dados.tipo !== 'adm' || !dados.login || dados.exp < Date.now()) return null;
    return dados;
  } catch {
    return null;
  }
}

// Middleware das rotas do painel: exige "Authorization: Bearer <token>".
function autenticarAdm(req, res, next) {
  const [esquema, token] = (req.headers.authorization || '').split(' ');
  const dados = esquema === 'Bearer' ? lerTokenAdm(token) : null;
  if (!dados) return res.status(401).json({ erro: 'Sessão de administrador inválida ou expirada.' });
  req.adm = { login: dados.login };
  next();
}

// ── Rotas de Autenticação ──
app.post('/login', limiteLogin, async (req, res) => {
  const { login, senha } = req.body;
  if (!login || !senha || !(await db.validarLogin(login, senha))) {
    return res.json({ sucesso: false });
  }
  res.json({ sucesso: true, token: gerarTokenAdm(login) });
});

app.post('/loginUsuario', limiteLogin, async (req, res) => {
  const { email, senha } = req.body;
  if (!email || !senha) return res.status(400).json({ sucesso: false, mensagem: 'Email e senha são obrigatórios' });
  try {
    return res.json(await db.validarLoginUsuario(email, senha));
  } catch (error) {
    console.error(error);
    return res.status(500).json({ sucesso: false, mensagem: 'Erro interno do servidor' });
  }
});

app.post('/loginOng', limiteLogin, async (req, res) => {
  const { email, senha } = req.body;
  if (!email || !senha) return res.status(400).json({ sucesso: false, mensagem: 'Email e senha são obrigatórios' });
  try {
    return res.json(await db.validarLoginOng(email, senha));
  } catch (error) {
    console.error(error);
    return res.status(500).json({ sucesso: false, mensagem: 'Erro interno do servidor' });
  }
});

// ── Recuperação de senha ──
const MSG_GENERICA_ENVIO = 'Se o e-mail estiver cadastrado, você receberá um código em instantes.';
const TIPOS_VALIDOS = ['usuario', 'ong'];

// Cria um código de confirmação de e-mail e manda pelo Brevo. Lança erro se o envio falhar.
async function enviarCodigoConfirmacao(email, tipo, identificador) {
  const codigo = await db.criarCodigoRecuperacao(email, tipo, identificador, db.TABELA_CONFIRMACAO);
  await enviarEmailBrevo({
    para: email,
    assunto: `${codigo} é o seu código de confirmação — Mútuo`,
    html: htmlEmailCodigo(codigo, 'confirmacao')
  });
}

// Passo 1: solicita o código.
app.post('/esqueciSenha', limiteEnvioEmail, async (req, res) => {
  const body = req.body || {};
  const email = String(body.email || '').trim().toLowerCase();
  const tipo = String(body.tipo || '').trim().toLowerCase();

  if (!email || !TIPOS_VALIDOS.includes(tipo)) {
    return res.status(400).json({ sucesso: false, mensagem: 'Informe o e-mail e o tipo de conta.' });
  }

  try {
    const conta = await db.buscarContaParaRecuperacao(email, tipo);

    // Conta não existe: resposta genérica (não revela nada).
    if (!conta) return res.json({ sucesso: true, mensagem: MSG_GENERICA_ENVIO });

    // Cooldown de 60s: não gera nem envia de novo, mas responde igual.
    const seg = await db.segundosDesdeUltimoCodigo(email, tipo);
    if (seg !== null && seg < 60) return res.json({ sucesso: true, mensagem: MSG_GENERICA_ENVIO });

    const codigo = await db.criarCodigoRecuperacao(email, tipo, conta.identificador);

    try {
      await enviarEmailBrevo({
        para: email,
        assunto: `${codigo} é o seu código de recuperação — Mútuo`,
        html: htmlEmailCodigo(codigo)
      });
    } catch (errEnvio) {
      console.error('Erro ao enviar e-mail (Brevo):', errEnvio.message);
      return res.status(502).json({ sucesso: false, mensagem: 'Não foi possível enviar o e-mail agora. Tente novamente em instantes.' });
    }

    return res.json({ sucesso: true, mensagem: MSG_GENERICA_ENVIO });
  } catch (err) {
    console.error('Erro em /esqueciSenha:', err);
    return res.status(500).json({ sucesso: false, mensagem: 'Erro interno. Tente novamente.' });
  }
});

// Passo 2: verifica o código (sem consumir) — permite avançar pra tela da nova senha.
app.post('/verificarCodigo', limiteCodigo, async (req, res) => {
  const body = req.body || {};
  const email = String(body.email || '').trim().toLowerCase();
  const tipo = String(body.tipo || '').trim().toLowerCase();
  const codigo = String(body.codigo || '').trim();

  if (!email || !TIPOS_VALIDOS.includes(tipo) || !/^\d{6}$/.test(codigo)) {
    return res.status(400).json({ sucesso: false, mensagem: 'Código inválido.' });
  }

  try {
    const r = await db.conferirCodigoRecuperacao(email, tipo, codigo);
    if (!r.valido) {
      return res.status(400).json({ sucesso: false, mensagem: r.mensagem, tentativasRestantes: r.tentativasRestantes });
    }
    return res.json({ sucesso: true });
  } catch (err) {
    console.error('Erro em /verificarCodigo:', err);
    return res.status(500).json({ sucesso: false, mensagem: 'Erro interno. Tente novamente.' });
  }
});

// Passo 3: redefine a senha (confere o código de novo e consome).
app.post('/redefinirSenha', limiteCodigo, async (req, res) => {
  const body = req.body || {};
  const email = String(body.email || '').trim().toLowerCase();
  const tipo = String(body.tipo || '').trim().toLowerCase();
  const codigo = String(body.codigo || '').trim();
  const novaSenha = String(body.novaSenha || '');

  if (!email || !TIPOS_VALIDOS.includes(tipo) || !/^\d{6}$/.test(codigo)) {
    return res.status(400).json({ sucesso: false, mensagem: 'Dados inválidos.' });
  }
  if (novaSenha.length < 8) {
    return res.status(400).json({ sucesso: false, mensagem: 'A senha deve ter no mínimo 8 caracteres.' });
  }

  try {
    const r = await db.conferirCodigoRecuperacao(email, tipo, codigo);
    if (!r.valido) {
      return res.status(400).json({ sucesso: false, mensagem: r.mensagem, tentativasRestantes: r.tentativasRestantes });
    }

    const ok = await db.redefinirSenhaComCodigo(tipo, r.registro.identificador, r.registro.id, novaSenha);
    if (!ok) return res.status(500).json({ sucesso: false, mensagem: 'Não foi possível atualizar a senha.' });

    return res.json({ sucesso: true, mensagem: 'Senha redefinida com sucesso!' });
  } catch (err) {
    console.error('Erro em /redefinirSenha:', err);
    return res.status(500).json({ sucesso: false, mensagem: 'Erro interno. Tente novamente.' });
  }
});

// ── Confirmação de e-mail ──
const MSG_GENERICA_REENVIO = 'Se houver um cadastro pendente com esse e-mail, enviamos um novo código.';

app.post('/confirmarEmail', limiteCodigo, async (req, res) => {
  const body = req.body || {};
  const email = String(body.email || '').trim().toLowerCase();
  const tipo = String(body.tipo || '').trim().toLowerCase();
  const codigo = String(body.codigo || '').trim();

  if (!email || !TIPOS_VALIDOS.includes(tipo) || !/^\d{6}$/.test(codigo)) {
    return res.status(400).json({ sucesso: false, mensagem: 'Código inválido.' });
  }

  try {
    const r = await db.conferirCodigoRecuperacao(email, tipo, codigo, db.TABELA_CONFIRMACAO);
    if (!r.valido) {
      return res.status(400).json({ sucesso: false, mensagem: r.mensagem, tentativasRestantes: r.tentativasRestantes });
    }
    const ok = await db.marcarEmailVerificado(tipo, r.registro.identificador, r.registro.id);
    if (!ok) return res.status(500).json({ sucesso: false, mensagem: 'Não foi possível confirmar o e-mail.' });
    return res.json({ sucesso: true, mensagem: 'E-mail confirmado! Agora é só entrar.' });
  } catch (err) {
    console.error('Erro em /confirmarEmail:', err);
    return res.status(500).json({ sucesso: false, mensagem: 'Erro interno. Tente novamente.' });
  }
});

app.post('/reenviarConfirmacao', limiteEnvioEmail, async (req, res) => {
  const body = req.body || {};
  const email = String(body.email || '').trim().toLowerCase();
  const tipo = String(body.tipo || '').trim().toLowerCase();

  if (!email || !TIPOS_VALIDOS.includes(tipo)) {
    return res.status(400).json({ sucesso: false, mensagem: 'Informe o e-mail e o tipo de conta.' });
  }

  try {
    const conta = await db.buscarContaParaConfirmacao(email, tipo);
    // Conta não existe ou já confirmada: resposta genérica (não revela nada).
    if (!conta || conta.verificado) return res.json({ sucesso: true, mensagem: MSG_GENERICA_REENVIO });

    const seg = await db.segundosDesdeUltimoCodigo(email, tipo, db.TABELA_CONFIRMACAO);
    if (seg !== null && seg < 60) return res.json({ sucesso: true, mensagem: MSG_GENERICA_REENVIO });

    try {
      await enviarCodigoConfirmacao(email, tipo, conta.identificador);
    } catch (errEnvio) {
      console.error('Erro ao enviar código de confirmação (Brevo):', errEnvio.message);
      return res.status(502).json({ sucesso: false, mensagem: 'Não foi possível enviar o e-mail agora. Tente novamente em instantes.' });
    }
    return res.json({ sucesso: true, mensagem: MSG_GENERICA_REENVIO });
  } catch (err) {
    console.error('Erro em /reenviarConfirmacao:', err);
    return res.status(500).json({ sucesso: false, mensagem: 'Erro interno. Tente novamente.' });
  }
});

// ── LGPD: baixar dados e excluir conta ──
// Sem token de usuário (item 1.1), a conta é identificada por e-mail + senha.
async function identificarContaPorSenha(body) {
  const email = String(body.email || '').trim();
  const senha = String(body.senha || '');
  const tipo = String(body.tipo || '').trim().toLowerCase();

  if (!email || !senha || !TIPOS_VALIDOS.includes(tipo)) {
    return { status: 400, mensagem: 'Informe e-mail, senha e tipo de conta.' };
  }
  const r = tipo === 'ong'
    ? await db.validarLoginOng(email, senha)
    : await db.validarLoginUsuario(email, senha);
  if (!r || !r.sucesso || !r.usuario) {
    return { status: 401, mensagem: 'Senha incorreta.' };
  }
  const id = tipo === 'ong' ? String(r.usuario.cnpj) : String(r.usuario.cpf);
  return { tipo, id, email: r.usuario.email };
}

// Junta os dados da conta. Cada parte em seu próprio try: se uma falhar,
// o resto ainda é exportado (e a parte que falhou vai como null).
async function montarExportacao(tipo, id) {
  const parte = async (nome, fn) => {
    try {
      const valor = await fn();
      // As funções do db.js devolvem { error } em vez de lançar.
      if (valor && !Array.isArray(valor) && valor.error) throw new Error(valor.error);
      return valor;
    } catch (err) {
      console.error(`Exportação LGPD: falha em "${nome}":`, err.message);
      return null;
    }
  };

  const base = { exportadoEm: new Date().toISOString(), plataforma: 'Mútuo', tipoConta: tipo };

  if (tipo === 'usuario') {
    return {
      ...base,
      perfil: await parte('perfil', () => db.getUsuarioPorCpf(id)),
      servicosOferecidos: await parte('servicosOferecidos', () => db.getServicosUsuario(id)),
      solicitacoesFeitas: await parte('solicitacoesFeitas', () => db.getSolicitacoesUsuario(id)),
      solicitacoesRecebidas: await parte('solicitacoesRecebidas', () => db.getSolicitacoesPrestador(id)),
      participacoesEmOngs: await parte('participacoesEmOngs', () => db.getSolicitacoesOngUsuario(id)),
      certificados: await parte('certificados', () => db.buscarCertificadosPorUsuario(id)),
      conversas: await parte('conversas', () => db.getConversasDaConta('usuario', id))
    };
  }
  return {
    ...base,
    perfil: await parte('perfil', () => db.getOngPorCnpj(id)),
    servicos: await parte('servicos', () => db.getServicosOng(id)),
    solicitacoesRecebidas: await parte('solicitacoesRecebidas', () => db.getSolicitacoesOng(id)),
    certificadosEmitidos: await parte('certificadosEmitidos', () => db.buscarCertificadosPorOng(id)),
    conversas: await parte('conversas', () => db.getConversasDaConta('ong', id))
  };
}

app.post('/minhaConta/dados', limiteLogin, async (req, res) => {
  try {
    const conta = await identificarContaPorSenha(req.body || {});
    if (conta.status) return res.status(conta.status).json({ sucesso: false, mensagem: conta.mensagem });

    const dados = await montarExportacao(conta.tipo, conta.id);

    if (req.body.enviarPorEmail) {
      const json = JSON.stringify(dados, null, 2);
      try {
        await enviarEmailBrevo({
          para: conta.email, // e-mail do banco, nunca o do body
          assunto: 'Seus dados no Mútuo',
          html: '<p>Olá! Em anexo estão os dados da sua conta no Mútuo, em formato JSON, como você pediu.</p>',
          anexos: [{ nome: 'meus-dados-mutuo.json', conteudoBase64: Buffer.from(json, 'utf8').toString('base64') }]
        });
      } catch (errEnvio) {
        console.error('Exportação LGPD: falha ao enviar e-mail:', errEnvio.message);
        return res.status(502).json({ sucesso: false, mensagem: 'Não foi possível enviar o e-mail agora. Tente novamente em instantes.' });
      }
      return res.json({ sucesso: true, mensagem: 'Enviamos seus dados para o e-mail da sua conta.' });
    }

    return res.json({ sucesso: true, dados });
  } catch (err) {
    console.error('Erro em /minhaConta/dados:', err);
    return res.status(500).json({ sucesso: false, mensagem: 'Erro interno. Tente novamente.' });
  }
});

app.post('/minhaConta/excluir', limiteLogin, async (req, res) => {
  try {
    if (String((req.body || {}).confirmacao || '').trim().toUpperCase() !== 'EXCLUIR') {
      return res.status(400).json({ sucesso: false, mensagem: 'Digite EXCLUIR para confirmar.' });
    }
    const conta = await identificarContaPorSenha(req.body || {});
    if (conta.status) return res.status(conta.status).json({ sucesso: false, mensagem: conta.mensagem });

    await db.anonimizarConta(conta.tipo, conta.id);
    return res.json({ sucesso: true, mensagem: 'Sua conta foi excluída.' });
  } catch (err) {
    console.error('Erro em /minhaConta/excluir:', err);
    return res.status(500).json({ sucesso: false, mensagem: 'Não foi possível excluir a conta agora. Tente novamente.' });
  }
});

// ── Rotas de Usuários ──
// Resposta de erro de cadastro sem expor a mensagem do banco.
function responderErroCadastro(e, res, documento) {
  if (e && e.code === 'ER_DUP_ENTRY') {
    const msg = `Já existe uma conta com esse ${documento} ou e-mail.`;
    return res.status(409).json({ sucesso: false, erro: msg, mensagem: msg });
  }
  console.error('Erro no cadastro:', e);
  const msg = 'Não foi possível concluir o cadastro. Tente novamente.';
  return res.status(500).json({ sucesso: false, erro: msg, mensagem: msg });
}

app.get('/usuarios', autenticarAdm, async (req, res) => res.json(await db.getUsuarios()));
app.post('/usuarios', limiteEnvioEmail, async (req, res) => {
  try {
    const id = await db.cadastrarUsuario(req.body);
    const email = String(req.body.email || '').trim().toLowerCase();

    // Falha no e-mail não desfaz o cadastro: a pessoa pode pedir reenvio na tela de confirmação.
    let emailEnviado = true;
    try {
      await enviarCodigoConfirmacao(email, 'usuario', String(req.body.cpf));
    } catch (errEnvio) {
      emailEnviado = false;
      console.error('Cadastro de usuário: falha ao enviar código de confirmação:', errEnvio.message);
    }
    res.json({ sucesso: true, id, confirmacaoPendente: true, emailEnviado });
  } catch (e) {
    responderErroCadastro(e, res, 'CPF');
  }
});

// Busca os dados completos de UM usuário específico (usado na tela de perfil)
app.get('/usuarios/:cpf', async (req, res) => {
  const usuario = await db.getUsuarioPorCpf(req.params.cpf);
  if (!usuario) return res.status(404).json({ erro: 'Usuário não encontrado' });
  if (usuario.error) return res.status(500).json({ erro: usuario.error });
  res.json(usuario);
});

app.put('/usuarios/:cpf', autenticarAdm, async (req, res) => {
  const { ativo, pontos, horas } = req.body;
  res.json(await db.alterUsuario(req.params.cpf, ativo, pontos, horas));
});


// Atualiza os campos editáveis do perfil do usuário (nome, email, telefone, cidade)
app.put('/usuarios/:cpf/perfil', async (req, res) => {
  const { nome, email, telefone, cidade } = req.body;
  if (!nome || !email) {
    return res.status(400).json({ erro: 'Nome e e-mail são obrigatórios' });
  }
  const resultado = await db.atualizarDadosUsuario(req.params.cpf, { nome, email, telefone, cidade });
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json(resultado);
});

// ── Rotas de ONGs e Serviços ──
app.get('/ongs', autenticarAdm, async (req, res) => res.json(await db.getONGs()));
app.post('/ongs', limiteEnvioEmail, async (req, res) => {
  try {
    const id = await db.cadastrarOng(req.body);
    const email = String(req.body.email || '').trim().toLowerCase();

    let emailEnviado = true;
    try {
      await enviarCodigoConfirmacao(email, 'ong', String(req.body.cnpj));
    } catch (errEnvio) {
      emailEnviado = false;
      console.error('Cadastro de ONG: falha ao enviar código de confirmação:', errEnvio.message);
    }
    res.json({ sucesso: true, id, confirmacaoPendente: true, emailEnviado });
  } catch (e) {
    responderErroCadastro(e, res, 'CNPJ');
  }
});

// Busca os dados completos de UMA ong específica (usado na tela de perfil)
// Já inclui os pontos da ONG na mesma resposta.
app.get('/ongs/:cnpj', async (req, res) => {
  const ong = await db.getOngPorCnpj(req.params.cnpj);
  if (!ong) return res.status(404).json({ erro: 'ONG não encontrada' });
  if (ong.error) return res.status(500).json({ erro: ong.error });

  await db.verificarBonusMensalOng(req.params.cnpj);

  const pontos = await db.countPontosOng(req.params.cnpj);
  const servicos = await db.buscarServicosAtivosOng(req.params.cnpj);

  res.json({ ...ong, pontos, servicos });
});

// Total de CPFs distintos que já realizaram serviços para a ONG.
app.get('/ongs/:cnpj/voluntarios-realizados', async (req, res) => {
  try {
    const totalVoluntarios = await db.contarVoluntariosOng(req.params.cnpj);
    res.json({ totalVoluntarios });
  } catch (e) {
    res.status(500).json({ erro: e.message });
  }
});

app.put('/ongs/:cnpj', autenticarAdm, async (req, res) => {
  const { ativo, responsavel, foco } = req.body;
  res.json(await db.alterONG(req.params.cnpj, ativo, responsavel, foco));
});

// Atualiza os campos editáveis do perfil da ONG (nome, email, telefone)
app.put('/ongs/:cnpj/perfil', async (req, res) => {
  const { nomeOng, email, telefone, cidade } = req.body;
  if (!nomeOng || !email) {
    return res.status(400).json({ erro: 'Nome e e-mail são obrigatórios' });
  }
  const resultado = await db.atualizarDadosOng(req.params.cnpj, { nomeOng, email, telefone, cidade });
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json(resultado);
});

app.get('/servicos', autenticarAdm, async (req, res) => res.json(await db.getServicos()));


// ── Cadastro de Serviço da ONG ──
app.post('/servicos/ong', uploadServico.single('imagem'), async (req, res) => {
  try {
    const { nomeServico, descricao, foco, duracao, cnpj, pontos } = req.body;

    if (!nomeServico || !descricao || !foco || !duracao || !cnpj || !pontos) {
      return res.status(400).json({ erro: 'Preencha todos os campos obrigatórios.' });
    }

    const pontosNum = Number(pontos);
    if (pontosNum < 10 || pontosNum > 50) {
      return res.status(400).json({ erro: 'Os pontos devem estar entre 10 e 50.' });
    }

    // ── Checagem do limite de serviços por plano ──
    const premium = await db.isOngPremium(cnpj);
    const limite = premium ? 10 : 5;
    const totalAtual = await db.contarServicosAtivosOng(cnpj);

    if (totalAtual >= limite) {
      return res.status(403).json({
        erro: premium
          ? `Você atingiu o limite de ${limite} serviços do plano Premium.`
          : `Você atingiu o limite de ${limite} serviços do plano gratuito. Assine o Premium para cadastrar até 10 serviços.`
      });
    }

    const imagem = req.file ? req.file.filename : null;
    const imagemDados = req.file ? fs.readFileSync(req.file.path) : null;
    const imagemTipo = req.file ? req.file.mimetype : null;

    const moderacao = await avaliarServico({
      nome: nomeServico, descricao, foco, imagemBuffer: imagemDados, imagemMime: imagemTipo
    });

    if (moderacao.status === 'BLOQUEADO') {
      // Não grava nada: apaga a imagem que o multer já salvou em disco.
      if (req.file?.path) { try { fs.unlinkSync(req.file.path); } catch (e) { /* ignora */ } }
      return res.json({ sucesso: false, moderacao: true, status: 'BLOQUEADO', mensagem: moderacao.mensagemUsuario });
    }

    const id = await db.cadastrarServicoOng({
      nomeServico, cnpj, horas: duracao, descricao, foco, imagem, imagemDados, imagemTipo,
      pontos: pontosNum, moderacao
    });

    console.log('[moderacao]', JSON.stringify({
      servicoId: id, tipoCriador: 'ong', status: moderacao.status,
      categoria: moderacao.categoria, confianca: moderacao.confianca
    }));

    res.json({
      sucesso: true, id, imagem: imagem ? `/uploads/servicos/${imagem}` : null,
      status: moderacao.status, mensagem: moderacao.mensagemUsuario
    });
  } catch (e) {
    res.status(500).json({ sucesso: false, erro: e.message });
  }
});
// Lista os serviços cadastrados por um usuário comum
app.get('/servicos/usuario/:cpf', async (req, res) => {
  const servicos = await db.getServicosUsuario(req.params.cpf);
  if (servicos.error) return res.status(500).json({ erro: servicos.error });
  res.json(servicos);
});

// Busca um serviço específico (para preencher o formulário de edição)
app.get('/servicos/:id', async (req, res) => {
  try {
    const servico = await db.getServicoPorId(req.params.id);
    if (!servico) return res.status(404).json({ erro: 'Serviço não encontrado.' });
    if (servico.error) return res.status(500).json({ erro: servico.error });

    res.json({
      ...servico,
      imagem: servico.imagem ? `/uploads/servicos/${servico.imagem}` : null
    });
  } catch (e) {
    res.status(500).json({ erro: e.message });
  }
});

// Atualiza um serviço do usuário
app.put('/servicos/:id', uploadServico.single('imagem'), async (req, res) => {
  try {
    const { nomeServico, descricao, foco, duracao, pontos } = req.body;

    if (!nomeServico || !descricao || !foco || !duracao || !pontos) {
      return res.status(400).json({ erro: 'Preencha todos os campos obrigatórios.' });
    }

    const pontosNum = Number(pontos);
    if (pontosNum < 10 || pontosNum > 50) {
      return res.status(400).json({ erro: 'Os pontos devem estar entre 10 e 50.' });
    }

    const imagem = req.file ? req.file.filename : null;
    const imagemDados = req.file ? fs.readFileSync(req.file.path) : null;
    const imagemTipo = req.file ? req.file.mimetype : null;
    const atual = await db.getServicoPorId(req.params.id);

    // O banco guarda o foco normalizado: compara normalizado pra não reavaliar à toa
    const norm = (v) => String(v ?? '').trim().toLowerCase();
    const mudouConteudo = !atual || atual.nomeServico !== nomeServico
      || atual.descricao !== descricao || norm(atual.foco) !== norm(foco) || !!imagem;

    let moderacao = null;
    if (mudouConteudo) {
      moderacao = await avaliarServico({
        nome: nomeServico, descricao, foco, imagemBuffer: imagemDados, imagemMime: imagemTipo
      });
      if (moderacao.status === 'BLOQUEADO') {
        if (req.file?.path) { try { fs.unlinkSync(req.file.path); } catch (e) { /* ignora */ } }
        return res.json({ sucesso: false, moderacao: true, status: 'BLOQUEADO', mensagem: moderacao.mensagemUsuario });
      }
    }

    await db.atualizarServico(req.params.id, {
      nomeServico, descricao, foco, duracao, imagem, imagemDados, imagemTipo,
      pontos: pontosNum,   // ← novo
      moderacao
    });

    res.json({ sucesso: true, status: moderacao?.status, mensagem: moderacao?.mensagemUsuario });
  } catch (e) {
    res.status(500).json({ sucesso: false, erro: e.message });
  }
});

// Lista os serviços cadastrados por uma ONG (útil pro perfil dela)
app.get('/servicos/ong/:cnpj', async (req, res) => {
  const servicos = await db.getServicosOng(req.params.cnpj);
  if (servicos.error) return res.status(500).json({ erro: servicos.error });
  res.json(servicos);
});

// Busca os dados de UM serviço específico da ONG (usado na tela de edição)
app.get('/servicos/ong/detalhe/:id', async (req, res) => {
  const servico = await db.getServicoOngPorId(req.params.id);
  if (!servico) return res.status(404).json({ erro: 'Serviço não encontrado' });
  res.json(servico);
});

// Atualiza um serviço existente da ONG
app.put('/servicos/ong/:id', uploadServico.single('imagem'), async (req, res) => {
  const { nomeServico, descricao, foco, duracao, pontos } = req.body;

  if (!nomeServico || !descricao || !foco || !duracao || !pontos) {
    return res.status(400).json({ erro: 'Preencha todos os campos obrigatórios.' });
  }

  const pontosNum = Number(pontos);
  if (pontosNum < 10 || pontosNum > 50) {
    return res.status(400).json({ erro: 'Os pontos devem estar entre 10 e 50.' });
  }

  const imagem = req.file ? req.file.filename : null;
  const imagemDados = req.file ? fs.readFileSync(req.file.path) : null;
  const imagemTipo = req.file ? req.file.mimetype : null;
  const atual = await db.getServicoOngPorId(req.params.id);

  // O banco guarda o foco normalizado: compara normalizado pra não reavaliar à toa
  const norm = (v) => String(v ?? '').trim().toLowerCase();
  const mudouConteudo = !atual || atual.nomeServico !== nomeServico
    || atual.descricao !== descricao || norm(atual.foco) !== norm(foco) || !!imagem;

  let moderacao = null;
  if (mudouConteudo) {
    moderacao = await avaliarServico({
      nome: nomeServico, descricao, foco, imagemBuffer: imagemDados, imagemMime: imagemTipo
    });
    if (moderacao.status === 'BLOQUEADO') {
      if (req.file?.path) { try { fs.unlinkSync(req.file.path); } catch (e) { /* ignora */ } }
      return res.json({ sucesso: false, moderacao: true, status: 'BLOQUEADO', mensagem: moderacao.mensagemUsuario });
    }
  }

  const resultado = await db.atualizarServicoOng(req.params.id, {
    nomeServico, descricao, foco, horas: duracao, imagem, imagemDados, imagemTipo,
    pontos: pontosNum, moderacao
  });
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json({ sucesso: true, status: moderacao?.status, mensagem: moderacao?.mensagemUsuario });
});

// Muda o status "ativo" do serviço da ONG (soft delete: ativo 1 -> 0)
app.patch('/servicos/ong/:id/status', async (req, res) => {
  const { ativo } = req.body;
  if (ativo === undefined) {
    return res.status(400).json({ erro: 'Informe o campo "ativo".' });
  }
  const resultado = await db.alterarStatusServicoOng(req.params.id, ativo);
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json(resultado);
});

// ── Rotas de Solicitações ──
app.get('/solicitacoes', autenticarAdm, async (req, res) => res.json(await db.getSolicitacoes()));
app.put('/solicitacoes/:cod', async (req, res) => {
  const { statusS, statusE, pontos } = req.body;
  const resultado = await db.alterSolicitacao(req.params.cod, statusS, statusE, pontos);

  // Avisa o solicitador que o prestador respondeu (aceitou/recusou).
  const info = await db.getSolicitacaoBasica(req.params.cod);
  if (info) {
    io.to(`usuario:${info.codUsuario}`).emit('solicitacao:atualizada', {
      codSolicitacao: req.params.cod,
      statusSolicitacao: statusS
    });
    enviarPush('usuario', info.codUsuario, {
      titulo: info.nomeServico || 'Solicitação',
      corpo: statusS === 'Aceita'
        ? 'Sua solicitação foi aceita!'
        : `Sua solicitação foi ${(statusS || 'atualizada').toLowerCase()}.`,
      dados: { tipo: 'solicitacao' }
    });
  }

  res.json(resultado);
});

// ── Rotas Premium ──
app.get('/premium', autenticarAdm, async (req, res) => res.json(await db.getPremium()));
app.get('/premium/contas', autenticarAdm, async (req, res) => {
  const contas = await db.getContasPremium();
  if (contas.error) return res.status(500).json({ erro: contas.error });
  res.json(contas);
});
app.get('/stats/premium-total', autenticarAdm, async (req, res) => res.json(await db.countPremiumTotal()));
app.get('/stats/atrasadas', autenticarAdm, async (req, res) => res.json(await db.countAtrasadas()));
app.get('/stats/receita', autenticarAdm, async (req, res) => res.json(await db.countReceita()));

// ── Rotas de Administrador ──
// O login do admin vem sempre do token, nunca do body.
app.put('/adm/login', autenticarAdm, async (req, res) => {
  const { novoLogin } = req.body;
  if (!novoLogin) return res.status(400).json({ erro: 'Informe o novo login.' });
  const resultado = await db.alterarLoginAdm(req.adm.login, novoLogin);
  // O token antigo carrega o login antigo, então devolve um novo.
  if (resultado.success) resultado.token = gerarTokenAdm(novoLogin);
  res.json(resultado);
});
app.put('/adm/senha', autenticarAdm, async (req, res) => {
  const { senhaAtual, novaSenha } = req.body;
  if (!senhaAtual || !novaSenha) return res.status(400).json({ erro: 'Informe a senha atual e a nova.' });
  res.json(await db.alterarSenhaAdm(req.adm.login, senhaAtual, novaSenha));
});
app.post('/adm/cadastrar', autenticarAdm, async (req, res) => {
  const { novoLogin, novaSenha } = req.body;
  if (!novoLogin || !novaSenha) return res.status(400).json({ erro: 'Informe login e senha.' });
  res.json(await db.cadastrarAdm(novoLogin, novaSenha));
});

// Ações do painel que têm rota parecida usada pelo site/app. Ficam em /adm
// para exigir o token sem quebrar o site e o app.
app.put('/adm/servicos/:cod', autenticarAdm, async (req, res) => {
  const { ativo, horas, foco, nota } = req.body;
  res.json(await db.alterServico(req.params.cod, ativo, horas, foco, nota));
});
app.put('/adm/solicitacoes/:cod', autenticarAdm, async (req, res) => {
  const { statusS, statusE, pontos } = req.body;
  res.json(await db.alterSolicitacao(req.params.cod, statusS, statusE, pontos));
});
app.put('/adm/usuarios/:cpf/premium', autenticarAdm, async (req, res) => {
  const resultado = await db.atualizarPremiumUsuario(req.params.cpf, 0);
  if (resultado.error) return res.status(500).json({ sucesso: false, erro: resultado.error });
  if (!resultado.success) return res.status(404).json({ sucesso: false, erro: 'Usuário não encontrado.' });
  res.json({ sucesso: true, premium: 0 });
});
app.put('/adm/ongs/:cnpj/premium', autenticarAdm, async (req, res) => {
  const resultado = await db.atualizarPremiumOng(req.params.cnpj, 0);
  if (resultado.error) return res.status(500).json({ sucesso: false, erro: resultado.error });
  if (!resultado.success) return res.status(404).json({ sucesso: false, erro: 'ONG não encontrada.' });
  res.json({ sucesso: true, premium: 0 });
});

// ── Moderação — fila de revisão ──
app.get('/moderacao/servicos', autenticarAdm, async (req, res) => {
  const servicos = await db.getServicosParaRevisao();
  if (servicos.error) return res.status(500).json({ erro: servicos.error });
  res.json(servicos);
});

app.put('/moderacao/servicos/:tipo/:id', autenticarAdm, async (req, res) => {
  const { tipo, id } = req.params;
  const { acao } = req.body || {};

  if (!['usuario', 'ong'].includes(tipo)) {
    return res.status(400).json({ erro: 'Tipo inválido.' });
  }
  if (!['APROVAR', 'REJEITAR'].includes(acao)) {
    return res.status(400).json({ erro: 'Ação inválida.' });
  }

  // A IA nunca bane usuário: a decisão do admin afeta só o serviço.
  const novoStatus = acao === 'APROVAR' ? 'APROVADO' : 'BLOQUEADO';
  const resultado = await db.atualizarModeracaoServico(tipo, id, novoStatus, req.adm.login);
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json({ sucesso: true });
});

// ── Rotas de Estatísticas ──
app.get('/stats/:tipo', autenticarAdm, async (req, res) => {
  const tipo = req.params.tipo;
  const mapeamento = {
    'usuarios': db.countUsuarios, 'ongs': db.countONGs, 'servicos': db.countServicos,
    'horas': db.countHoras, 'usuarios-inativos': db.countUsuariosInativos,
    'pontos': db.countPontos, 'ongs-inativas': db.countONGsInativas,
    'premium': db.countPremium, 'servicos-cadastrados': db.countServicosCadastrados,
    'aceitas': db.countSolicitacoesAceitas, 'pendentes': db.countSolicitacoesPendentes,
    'recusadas': db.countSolicitacoesRecusadas, 'media-notas': db.mediaNotas
  };
  if (mapeamento[tipo]) res.json(await mapeamento[tipo]());
  else res.status(404).send('Não encontrado');
});

// ── Foto de Perfil (Usuário comum) ──
app.post('/perfil/foto', upload.single('fotoPerfil'), async (req, res) => {
  console.log(' CPF recebido:', req.body.cpf);
  console.log(' Arquivo recebido:', req.file);

  const cpf = req.body.cpf;
  if (!cpf) return res.status(400).json({ erro: 'CPF não informado' });
  if (!req.file) return res.status(400).json({ erro: 'Nenhum arquivo enviado' });

  const dados = fs.readFileSync(req.file.path);
  const resultado = await db.atualizarFotoPerfil(cpf, req.file.filename, dados, req.file.mimetype);
  console.log(' Resultado do banco:', resultado);

  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json({ sucesso: true, fotoPerfil: `/uploads/fotos/${req.file.filename}` });
});

app.get('/perfil/foto/:cpf', async (req, res) => {
  const foto = await db.getFotoPerfil(req.params.cpf);
  res.json({ fotoPerfil: foto ? `/uploads/fotos/${foto}` : null });
});

// ── Foto de Perfil (ONG) ──
app.post('/perfil/foto/ong', upload.single('fotoPerfil'), async (req, res) => {
  console.log(' CNPJ recebido:', req.body.cnpj);
  console.log(' Arquivo recebido:', req.file);

  const cnpj = req.body.cnpj;
  if (!cnpj) return res.status(400).json({ erro: 'CNPJ não informado' });
  if (!req.file) return res.status(400).json({ erro: 'Nenhum arquivo enviado' });

  const dados = fs.readFileSync(req.file.path);
  const resultado = await db.atualizarFotoPerfilOng(cnpj, req.file.filename, dados, req.file.mimetype);
  console.log(' Resultado do banco:', resultado);

  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json({ sucesso: true, fotoPerfil: `/uploads/fotos/${req.file.filename}` });
});

app.get('/perfil/foto/ong/:cnpj', async (req, res) => {
  const foto = await db.getFotoPerfilOng(req.params.cnpj);
  res.json({ fotoPerfil: foto ? `/uploads/fotos/${foto}` : null });
});
// Lista todos os serviços de ONGs ativos
app.get('/servicos-ong', async (req, res) => {
  const servicos = await db.getServicosOngTodos();
  if (servicos.error) return res.status(500).json({ erro: servicos.error });
  res.json(servicos);
});

// Lista todos os serviços de usuários ativos (usado na página de busca/vitrine)
app.get('/servicos-usuario', async (req, res) => {
  const servicos = await db.getServicosUsuarioTodos();
  if (servicos.error) return res.status(500).json({ erro: servicos.error });
  res.json(servicos);
});

// Cria uma nova solicitação (inscrição em um serviço)
app.post('/solicitacoes', async (req, res) => {
  try {
    const { codServico, codUsuario, pontos } = req.body;

    if (!codServico || !codUsuario) {
      return res.status(400).json({ erro: 'codServico e codUsuario são obrigatórios.' });
    }

    const resultado = await db.cadastrarSolicitacao(codServico, codUsuario, pontos || 0);
    if (resultado.error) return res.status(500).json({ erro: resultado.error });

    // Avisa o prestador em tempo real (badge) e por push (fechado/background).
    const [servico, solicitador] = await Promise.all([
      db.getServicoPorId(codServico),
      db.getUsuarioPorCpf(codUsuario)
    ]);
    if (servico && servico.idUsuario) {
      io.to(`usuario:${servico.idUsuario}`).emit('solicitacao:nova', {
        codSolicitacao: resultado.id,
        ong: false
      });
      enviarPush('usuario', servico.idUsuario, {
        titulo: solicitador?.nome || 'Nova solicitação',
        corpo: `Quer solicitar seu serviço "${servico.nomeServico}"`,
        dados: { tipo: 'solicitacao' }
      });
    }

    res.json(resultado);
  } catch (e) {
    res.status(500).json({ erro: e.message });
  }
});

app.get('/solicitacoes/prestador/:cpf', async (req, res) => {
  const solicitacoes = await db.getSolicitacoesPrestador(req.params.cpf);
  if (solicitacoes.error) return res.status(500).json({ erro: solicitacoes.error });
  res.json(solicitacoes);
});

app.get('/solicitacoes/usuario/:cpf', async (req, res) => {
  const solicitacoes = await db.getSolicitacoesUsuario(req.params.cpf);
  if (solicitacoes.error) return res.status(500).json({ erro: solicitacoes.error });
  res.json(solicitacoes);
});

app.get('/usuarios/:cpf/estatisticas', async (req, res) => {
  const stats = await db.getEstatisticasUsuario(req.params.cpf);
  if (stats.error) return res.status(500).json({ erro: stats.error });
  res.json(stats);
});

app.get('/usuarios/:cpf/dashboard', async (req, res) => {
  const dashboard = await db.getDashboardUsuario(req.params.cpf);
  if (dashboard.error) return res.status(500).json({ erro: dashboard.error });
  res.json(dashboard);
});



// Cria uma solicitação para um serviço de ONG
app.post('/solicitacoes-ong', async (req, res) => {
  try {
    const { codServico, codUsuario, pontos } = req.body;
    if (!codServico || !codUsuario) {
      return res.status(400).json({ erro: 'codServico e codUsuario são obrigatórios.' });
    }
    const resultado = await db.cadastrarSolicitacaoOng(codServico, codUsuario, pontos || 0);
    if (resultado.error) return res.status(500).json({ erro: resultado.error });

    // Avisa a ONG em tempo real (badge) e por push (fechado/background).
    const [servico, solicitador] = await Promise.all([
      db.getServicoOngPorId(codServico),
      db.getUsuarioPorCpf(codUsuario)
    ]);
    if (servico && servico.cnpj) {
      io.to(`ong:${servico.cnpj}`).emit('solicitacao:nova', {
        codSolicitacao: resultado.id,
        ong: true
      });
      enviarPush('ong', servico.cnpj, {
        titulo: solicitador?.nome || 'Nova solicitação',
        corpo: `Quer participar de "${servico.nomeServico}"`,
        dados: { tipo: 'solicitacao' }
      });
    }

    res.json(resultado);
  } catch (e) {
    res.status(500).json({ erro: e.message });
  }
});


// ROTAS CERTIFICADO
app.get('/certificados/:cpf', async (req, res) => {
  try {
    const dados = await db.buscarCertificadosPorUsuario(req.params.cpf);
    res.json(dados);
  } catch (e) {
    console.error('Erro ao buscar certificados:', e);
    res.status(500).json({ sucesso: false, erro: e.message });
  }
});

const puppeteer = require('puppeteer');
const QRCode = require('qrcode');
//const fs = require('fs');

app.get('/certificados/:cpf/:codSolicitacao/pdf', async (req, res) => {
  try {
    const dados = await db.buscarDadosCertificado(req.params.cpf, req.params.codSolicitacao);

    if (!dados) {
      return res.status(404).json({ erro: 'Certificado não encontrado.' });
    }

    let html = fs.readFileSync(path.join(__dirname, 'templates', 'certificado.html'), 'utf8');

    const dataFormatada = new Date(dados.dataConclusao || dados.dataSolicitacao).toLocaleDateString('pt-BR');

    // QR code que abre a página de verificação já com o código preenchido.
    // SITE_URL_PUBLICA = endereço onde a pasta web/ está publicada (sem barra no fim).
    let qrCodeHtml = '';
    const siteUrl = (process.env.SITE_URL_PUBLICA || '').replace(/\/+$/, '');
    if (siteUrl && dados.codigoVerificacao) {
      const urlVerificacao = `${siteUrl}/verificarCertificado.html?codigo=${encodeURIComponent(dados.codigoVerificacao)}`;
      const qrDataUrl = await QRCode.toDataURL(urlVerificacao, {
        margin: 1,
        width: 240,
        color: { dark: '#3A5A40', light: '#FFFFFF' }
      });
      qrCodeHtml = `<img class="qr-verificacao" src="${qrDataUrl}" alt="QR code de verificação">`;
    } else {
      console.warn('SITE_URL_PUBLICA não definida: certificado gerado sem QR code.');
    }

    html = html
      .replaceAll('{{nomeUsuario}}', escaparHtml(dados.nomeUsuario))
      .replaceAll('{{nomeServico}}', escaparHtml(dados.nomeServico))
      .replaceAll('{{nomeOng}}', escaparHtml(dados.nomeOng))
      .replaceAll('{{horas}}', escaparHtml(dados.horas))
      .replaceAll('{{dataConclusao}}', escaparHtml(dataFormatada))
      .replaceAll('{{codigoVerificacao}}', escaparHtml(dados.codigoVerificacao))
      .replaceAll('{{qrCode}}', qrCodeHtml);

    const browser = await puppeteer.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox'
      ]
    });

    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: 'networkidle0' });
    const pdfBuffer = await page.pdf({
      width: '297mm',
      height: '210mm',
      printBackground: true
    });
    await browser.close();

    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename=certificado-${dados.codSolicitacao}.pdf`
    });
    res.send(pdfBuffer);
  } catch (e) {
    console.error('Erro ao gerar certificado:', e);
    res.status(500).json({ erro: e.message });
  }
});

app.get('/verificar/:codigo', async (req, res) => {
  const dados = await db.verificarCertificado(req.params.codigo);
  if (!dados) return res.status(404).json({ valido: false });
  res.json({ valido: true, ...dados });
});

app.get('/certificados/ong/:cnpj', async (req, res) => {
  try {
    const dados = await db.buscarCertificadosPorOng(req.params.cnpj);
    res.json(dados);
  } catch (e) {
    console.error('Erro ao buscar certificados da ONG:', e);
    res.status(500).json({ sucesso: false, erro: e.message });
  }
});

// Lista solicitações recebidas por uma ONG
app.get('/solicitacoes-ong/prestador/:cnpj', async (req, res) => {
  const solicitacoes = await db.getSolicitacoesOng(req.params.cnpj);
  if (solicitacoes.error) return res.status(500).json({ erro: solicitacoes.error });
  res.json(solicitacoes);
});

// Aceita/recusa uma solicitação de serviço de ONG
app.put('/solicitacoes-ong/:cod', async (req, res) => {
  const { statusS, statusE, pontos } = req.body;
  const resultado = await db.alterSolicitacaoOng(req.params.cod, statusS, statusE, pontos);

  // Avisa o solicitador que a ONG respondeu (aceitou/recusou).
  const info = await db.getSolicitacaoOngBasica(req.params.cod);
  if (info) {
    io.to(`usuario:${info.codUsuario}`).emit('solicitacao:atualizada', {
      codSolicitacao: req.params.cod,
      statusSolicitacao: statusS
    });
    enviarPush('usuario', info.codUsuario, {
      titulo: info.nomeServico || 'Solicitação',
      corpo: statusS === 'Aceita'
        ? 'Sua solicitação foi aceita!'
        : `Sua solicitação foi ${(statusS || 'atualizada').toLowerCase()}.`,
      dados: { tipo: 'solicitacao' }
    });
  }

  res.json(resultado);
});

// Conta solicitações não lidas recebidas por uma ONG (badge).
app.get('/solicitacoes-ong/naolidas/:cnpj', async (req, res) => {
  const total = await db.contarNaoLidasOng(req.params.cnpj);
  if (total.error) return res.status(500).json({ erro: total.error });
  res.json({ total });
});

app.put('/solicitacoes-ong/:cod/lida', async (req, res) => {
  const resultado = await db.marcarSolicitacaoOngLida(req.params.cod);
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json(resultado);
});

// pontos e notificação lado da ong

app.get('/solicitacoes-ong/usuario/:cpf', async (req, res) => {
  const solicitacoes = await db.getSolicitacoesOngUsuario(req.params.cpf);
  if (solicitacoes.error) return res.status(500).json({ erro: solicitacoes.error });
  res.json(solicitacoes);
});

app.get('/solicitacoes-ong/confirmar/:cnpj', async (req, res) => {
  const solicitacoes = await db.getSolicitacoesOngParaConfirmar(req.params.cnpj);
  if (solicitacoes.error) return res.status(500).json({ erro: solicitacoes.error });
  res.json(solicitacoes);
});

app.put('/solicitacoes-ong/:cod/confirmar', async (req, res) => {
  const resultado = await db.confirmarSolicitacaoOng(req.params.cod);
  if (resultado.error) return res.status(400).json({ erro: resultado.error });
  res.json(resultado);
});

app.get('/solicitacoes-ong/recebidos/:cnpj', async (req, res) => {
  const solicitacoes = await db.getServicosRecebidosOng(req.params.cnpj);
  if (solicitacoes.error) return res.status(500).json({ erro: solicitacoes.error });
  res.json(solicitacoes);
});

app.get('/ongs/:cnpj/movimentacao', async (req, res) => {
  const resultado = await db.getMovimentacaoMensalOng(req.params.cnpj);
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json(resultado);
});

// ── Rota de Contato ──
app.post('/contato', limiteEnvioEmail, async (req, res) => {
  const body = req.body || {};
  const nome = String(body.nome || '').trim();
  const email = String(body.email || '').trim();
  const mensagem = String(body.mensagem || '').trim();

  if (!nome || !email || !mensagem) {
    return res.status(400).json({ sucesso: false, erro: 'Preencha todos os campos.' });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ sucesso: false, erro: 'Informe um e-mail válido.' });
  }
  if (nome.length > 120 || mensagem.length > 5000) {
    return res.status(400).json({ sucesso: false, erro: 'Mensagem grande demais.' });
  }

  try {
    await enviarEmailBrevo({
      para: process.env.EMAIL_CONTATO || 'equipe.mutuo@gmail.com',
      assunto: 'Nova mensagem - Contato Mútuo',
      responderPara: email,
      html: `
        <h3>Nova mensagem pelo formulário de contato</h3>
        <p><strong>Nome:</strong> ${escaparHtml(nome)}</p>
        <p><strong>E-mail:</strong> ${escaparHtml(email)}</p>
        <p><strong>Mensagem:</strong></p>
        <p>${escaparHtml(mensagem).replace(/\n/g, '<br>')}</p>
      `
    });
    res.json({ sucesso: true });
  } catch (erro) {
    console.error('Erro ao enviar e-mail de contato (Brevo):', erro.message);
    res.status(500).json({ sucesso: false, erro: 'Não foi possível enviar o e-mail.' });
  }
});

/// Lista os serviços em destaque (de usuários premium), exceto os do próprio usuário
app.get('/servicos-destaque', async (req, res) => {
  const { cpf } = req.query;
  const servicos = await db.getServicosDestaque(cpf);
  if (servicos.error) return res.status(500).json({ erro: servicos.error });
  res.json(servicos);
});

// Lista serviços perto de você (mesma cidade, usuários premium), exceto os do próprio usuário
app.get('/servicos-perto/:cidade', async (req, res) => {
  const { cpf } = req.query;
  const servicos = await db.getServicosPertoDeVoce(req.params.cidade, cpf);
  if (servicos.error) return res.status(500).json({ erro: servicos.error });
  res.json(servicos);
});

// ── Cadastro de Serviço do Usuário ──
app.post('/servicos', uploadServico.single('imagem'), async (req, res) => {
  try {
    const { nomeServico, descricao, foco, duracao, cpf, pontos } = req.body;

    if (!nomeServico || !descricao || !foco || !duracao || !cpf || !pontos) {
      return res.status(400).json({ erro: 'Preencha todos os campos obrigatórios.' });
    }

    const pontosNum = Number(pontos);
    if (pontosNum < 10 || pontosNum > 50) {
      return res.status(400).json({ erro: 'Os pontos devem estar entre 10 e 50.' });
    }

    // ── Checagem do limite de serviços por plano ──
    const premium = await db.isUsuarioPremium(cpf);
    const limite = premium ? 8 : 3;
    const totalAtual = await db.contarServicosAtivosUsuario(cpf);

    if (totalAtual >= limite) {
      return res.status(403).json({
        erro: premium
          ? `Você atingiu o limite de ${limite} serviços do plano Premium.`
          : `Você atingiu o limite de ${limite} serviços do plano gratuito. Assine o Premium para cadastrar até 8 serviços.`
      });
    }

    const imagem = req.file ? req.file.filename : null;
    const imagemDados = req.file ? fs.readFileSync(req.file.path) : null;
    const imagemTipo = req.file ? req.file.mimetype : null;

    const moderacao = await avaliarServico({
      nome: nomeServico, descricao, foco, imagemBuffer: imagemDados, imagemMime: imagemTipo
    });

    if (moderacao.status === 'BLOQUEADO') {
      // Não grava nada: apaga a imagem que o multer já salvou em disco.
      if (req.file?.path) { try { fs.unlinkSync(req.file.path); } catch (e) { /* ignora */ } }
      return res.json({ sucesso: false, moderacao: true, status: 'BLOQUEADO', mensagem: moderacao.mensagemUsuario });
    }

    const id = await db.cadastrarServico({
      nomeServico, descricao, foco, duracao, cpf, imagem, imagemDados, imagemTipo, pontos: pontosNum, moderacao
    });

    console.log('[moderacao]', JSON.stringify({
      servicoId: id, tipoCriador: 'usuario', status: moderacao.status,
      categoria: moderacao.categoria, confianca: moderacao.confianca
    }));

    res.json({
      sucesso: true, id, imagem: imagem ? `/uploads/servicos/${imagem}` : null,
      status: moderacao.status, mensagem: moderacao.mensagemUsuario
    });
  } catch (e) {
    res.status(500).json({ sucesso: false, erro: e.message });
  }
});

// Ativa/desativa o plano premium do usuário (usado no checkout simulado)
app.put('/usuarios/:cpf/premium', async (req, res) => {
  const premium = Number(req.body.premium);

  if (![0, 1].includes(premium)) {
    return res.status(400).json({
      sucesso: false,
      erro: 'O campo "premium" deve ser 0 ou 1.'
    });
  }

  const resultado = await db.atualizarPremiumUsuario(
    req.params.cpf,
    premium
  );

  if (resultado.error) {
    return res.status(500).json({
      sucesso: false,
      erro: resultado.error
    });
  }

  if (!resultado.success) {
    return res.status(404).json({
      sucesso: false,
      erro: 'Usuário não encontrado.'
    });
  }

  res.json({
    sucesso: true,
    premium
  });
});

app.put('/ongs/:cnpj/premium', async (req, res) => {
  const premium = Number(req.body.premium);

  if (![0, 1].includes(premium)) {
    return res.status(400).json({
      sucesso: false,
      erro: 'O campo "premium" deve ser 0 ou 1.'
    });
  }

  const resultado = await db.atualizarPremiumOng(
    req.params.cnpj,
    premium
  );

  if (resultado.error) {
    return res.status(500).json({
      sucesso: false,
      erro: resultado.error
    });
  }

  if (!resultado.success) {
    return res.status(404).json({
      sucesso: false,
      erro: 'ONG não encontrada.'
    });
  }

  res.json({
    sucesso: true,
    premium
  });
});
// Total de CPFs distintos que já realizaram serviços para a ONG
app.get(
  '/ongs/:cnpj/voluntarios-realizados',
  async (req, res) => {
    try {
      const totalVoluntarios =
        await db.contarVoluntariosOng(req.params.cnpj);
      res.json({
        totalVoluntarios
      });
    } catch (erro) {
      console.error(
        'Erro ao carregar voluntários da ONG:',
        erro.message
      );

      res.status(500).json({
        erro: 'Não foi possível carregar os voluntários.'
      });
    }
  }
);

// confirmação e avaliação

app.get('/solicitacoes/confirmar/:cpf', async (req, res) => {
  const solicitacoes = await db.getSolicitacoesParaConfirmar(req.params.cpf);
  if (solicitacoes.error) return res.status(500).json({ erro: solicitacoes.error });
  res.json(solicitacoes);
});

app.put('/solicitacoes/:cod/confirmar', async (req, res) => {
  const resultado = await db.confirmarSolicitacao(req.params.cod);
  if (resultado.error) return res.status(400).json({ erro: resultado.error });
  res.json(resultado);
});

app.post('/solicitacoes/:cod/avaliar', async (req, res) => {
  const { nota } = req.body;
  const resultado = await db.avaliarSolicitacao(req.params.cod, nota);
  if (resultado.error) return res.status(400).json({ erro: resultado.error });
  res.json(resultado);
});

app.post('/solicitacoes-ong/:cod/avaliar', async (req, res) => {
  const { nota } = req.body;
  const resultado = await db.avaliarSolicitacaoOng(req.params.cod, nota);
  if (resultado.error) return res.status(400).json({ erro: resultado.error });
  res.json(resultado);
});

app.put('/solicitacoes/:cod/lida', async (req, res) => {
  const resultado = await db.marcarSolicitacaoLida(req.params.cod);
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json(resultado);
});

app.get('/solicitacoes/naolidas/:cpf', async (req, res) => {
  const total = await db.contarNaoLidas(req.params.cpf);
  if (total.error) return res.status(500).json({ erro: total.error });
  res.json({ total });
});

app.get('/usuarios/:cpf/movimentacao', async (req, res) => {
  const resultado = await db.getMovimentacaoMensal(req.params.cpf);
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json(resultado);
});


// ── Rotas de Chat ──
app.post('/conversas', async (req, res) => {
  try {
    const { tipo1, id1, tipo2, id2 } = req.body;
    if (!tipo1 || !id1 || !tipo2 || !id2) {
      return res.status(400).json({ sucesso: false, erro: 'tipo1, id1, tipo2 e id2 são obrigatórios.' });
    }
    const conversa = await db.buscarOuCriarConversa(tipo1, id1, tipo2, id2);
    if (conversa.error) return res.status(500).json({ sucesso: false, erro: conversa.error });
    res.json({ sucesso: true, conversa });
  } catch (e) {
    res.status(500).json({ sucesso: false, erro: e.message });
  }
});

// Precisam vir antes de /conversas/:tipo/:id — ambas têm 2 segmentos após
// /conversas, e o Express casa pela primeira rota que corresponder ao formato.
app.get('/conversas/:conversaId/mensagens', async (req, res) => {
  const { desde, tipo, id } = req.query;
  const mensagens = await db.getMensagens(req.params.conversaId, desde, tipo, id);
  if (mensagens.error) return res.status(500).json({ erro: mensagens.error });
  res.json(mensagens);
});

app.post('/conversas/:conversaId/mensagens', async (req, res) => {
  try {
    const { tipo, id, conteudo } = req.body;
    if (!tipo || !id || !conteudo) {
      return res.status(400).json({ sucesso: false, erro: 'tipo, id e conteudo são obrigatórios.' });
    }

    const mensagem = await db.criarMensagem(req.params.conversaId, tipo, id, conteudo);
    if (mensagem.error) return res.status(500).json({ sucesso: false, erro: mensagem.error });

    const destino = await buscarOutroParticipante(req.params.conversaId, tipo, id);
    if (destino) io.to(`${destino.tipo}:${destino.id}`).emit('mensagem:nova', mensagem);

    res.json({ sucesso: true, mensagem });
  } catch (e) {
    res.status(500).json({ sucesso: false, erro: e.message });
  }
});

app.patch('/conversas/:conversaId/lida', async (req, res) => {
  try {
    const { tipo, id } = req.body;
    if (!tipo || !id) {
      return res.status(400).json({ sucesso: false, erro: 'tipo e id são obrigatórios.' });
    }

    const destino = await buscarOutroParticipante(req.params.conversaId, tipo, id);
    const resultado = await db.marcarConversaComoLida(req.params.conversaId, tipo, id);
    if (resultado.error) return res.status(500).json({ sucesso: false, erro: resultado.error });

    if (destino) io.to(`${destino.tipo}:${destino.id}`).emit('conversa:lida', req.params.conversaId);

    res.json(resultado);
  } catch (e) {
    res.status(500).json({ sucesso: false, erro: e.message });
  }
});

app.put('/conversas/:conversaId/limpar', async (req, res) => {
  try {
    const { tipo, id } = req.body;
    if (!tipo || !id) {
      return res.status(400).json({ sucesso: false, erro: 'tipo e id são obrigatórios.' });
    }
    const resultado = await db.limparConversaParaConta(req.params.conversaId, tipo, id);
    if (resultado.error) return res.status(400).json({ sucesso: false, erro: resultado.error });
    res.json(resultado);
  } catch (e) {
    res.status(500).json({ sucesso: false, erro: e.message });
  }
});

app.get('/conversas/:tipo/:id', async (req, res) => {
  const conversas = await db.getConversasDaConta(req.params.tipo, req.params.id);
  if (conversas.error) return res.status(500).json({ erro: conversas.error });
  res.json(conversas);
});

app.post('/notificacoes/token', async (req, res) => {
  try {
    const { tipo, identificador, token } = req.body;
    if (!tipo || !identificador || !token) {
      return res.status(400).json({ sucesso: false, erro: 'tipo, identificador e token são obrigatórios.' });
    }

    const resultado = await db.salvarTokenDispositivo(tipo, identificador, token);
    if (resultado.error) return res.status(500).json({ sucesso: false, erro: resultado.error });

    res.json(resultado);
  } catch (e) {
    res.status(500).json({ sucesso: false, erro: e.message });
  }
});

// Garante que qualquer erro sempre responda em JSON, nunca em HTML,
// e sem mandar detalhes internos (banco, stack) para o cliente.
// Precisa ficar DEPOIS de todas as rotas.
app.use((err, req, res, next) => {
  console.error('Erro capturado pelo middleware global:', err);

  if (err instanceof multer.MulterError) {
    const msg = err.code === 'LIMIT_FILE_SIZE'
      ? 'A imagem deve ter no máximo 3 MB.'
      : 'Não foi possível processar o arquivo enviado.';
    return res.status(400).json({ sucesso: false, erro: msg, mensagem: msg });
  }
  if (err.expor) {
    return res.status(err.status || 400).json({ sucesso: false, erro: err.message, mensagem: err.message });
  }
  if (err.type === 'entity.too.large') {
    return res.status(413).json({ sucesso: false, erro: 'Conteúdo grande demais.', mensagem: 'Conteúdo grande demais.' });
  }
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ sucesso: false, erro: 'Requisição inválida.', mensagem: 'Requisição inválida.' });
  }
  res.status(500).json({ sucesso: false, erro: 'Erro ao processar a requisição.', mensagem: 'Erro ao processar a requisição.' });
});


const PORT = process.env.PORT || 3000;
// Sobe só depois de criar tabelas/colunas: o login já lê email_verificado.
db.inicializarTabelas()
  .catch(err => console.error('Erro ao inicializar tabelas:', err))
  .finally(() => server.listen(PORT, () => console.log(`API rodando na porta ${PORT}`)));
