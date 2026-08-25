const express = require('express');
const cors    = require('cors');
const path    = require('path');
const multer  = require('multer');
const fs      = require('fs');
const db      = require('./db');
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS
  }
});
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json({ limit: '20mb' }));
app.use(express.urlencoded({ extended: true, limit: '20mb' }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

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
    else cb(new Error('Apenas imagens JPG, PNG ou WEBP são aceitas.'));
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
    else cb(new Error('Apenas imagens JPG, PNG ou WEBP são aceitas.'));
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



// ── Rotas de Autenticação ──
app.post('/login', async (req, res) => {
    const { login, senha } = req.body;
    res.json(await db.validarLogin(login, senha));
});

app.post('/loginUsuario', async (req, res) => {
  const { email, senha } = req.body;
  if (!email || !senha) return res.status(400).json({ sucesso: false, mensagem: 'Email e senha são obrigatórios' });
  try {
    return res.json(await db.validarLoginUsuario(email, senha));
  } catch (error) {
    console.error(error);
    return res.status(500).json({ sucesso: false, mensagem: 'Erro interno do servidor' });
  }
});

app.post('/loginOng', async (req, res) => {
  const { email, senha } = req.body;
  if (!email || !senha) return res.status(400).json({ sucesso: false, mensagem: 'Email e senha são obrigatórios' });
  try {
    return res.json(await db.validarLoginOng(email, senha));
  } catch (error) {
    console.error(error);
    return res.status(500).json({ sucesso: false, mensagem: 'Erro interno do servidor' });
  }
});

// ── Rotas de Usuários ──
app.get('/usuarios', async (req, res) => res.json(await db.getUsuarios()));
app.post('/usuarios', async (req, res) => {
    try {
        const id = await db.cadastrarUsuario(req.body);
        res.json({ sucesso: true, id });
    } catch (e) { res.status(500).json({ sucesso: false, erro: e.message }); }
});

// Busca os dados completos de UM usuário específico (usado na tela de perfil)
app.get('/usuarios/:cpf', async (req, res) => {
  const usuario = await db.getUsuarioPorCpf(req.params.cpf);
  if (!usuario) return res.status(404).json({ erro: 'Usuário não encontrado' });
  if (usuario.error) return res.status(500).json({ erro: usuario.error });
  res.json(usuario);
});

app.put('/usuarios/:cpf', async (req, res) => {
    const { ativo, pontos, horas } = req.body;
    res.json(await db.alterUsuario(req.params.cpf, ativo, pontos, horas));
});

// Atualiza os campos editáveis do perfil do usuário (nome, email, telefone)
app.put('/usuarios/:cpf/perfil', async (req, res) => {
  const { nome, email, telefone } = req.body;
  if (!nome || !email) {
    return res.status(400).json({ erro: 'Nome e e-mail são obrigatórios' });
  }
  const resultado = await db.atualizarDadosUsuario(req.params.cpf, { nome, email, telefone });
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json(resultado);
});

// ── Rotas de ONGs e Serviços ──
app.get('/ongs',  async (req, res) => res.json(await db.getONGs()));
app.post('/ongs', async (req, res) => {
    try {
        const id = await db.cadastrarOng(req.body);
        res.json({ sucesso: true, id });
    } catch (e) { res.status(500).json({ sucesso: false, erro: e.message }); }
});

// Busca os dados completos de UMA ong específica (usado na tela de perfil)
// Já inclui os pontos da ONG na mesma resposta.
app.get('/ongs/:cnpj', async (req, res) => {
  const ong = await db.getOngPorCnpj(req.params.cnpj);
  if (!ong) return res.status(404).json({ erro: 'ONG não encontrada' });
  if (ong.error) return res.status(500).json({ erro: ong.error });

  const pontos = await db.countPontosOng(req.params.cnpj);
  res.json({ ...ong, pontos });
});

app.put('/ongs/:cnpj', async (req, res) => {
    const { ativo, responsavel, foco } = req.body;
    res.json(await db.alterONG(req.params.cnpj, ativo, responsavel, foco));
});

// Atualiza os campos editáveis do perfil da ONG (nome, email, telefone)
app.put('/ongs/:cnpj/perfil', async (req, res) => {
  const { nomeOng, email, telefone } = req.body;
  if (!nomeOng || !email) {
    return res.status(400).json({ erro: 'Nome e e-mail são obrigatórios' });
  }
  const resultado = await db.atualizarDadosOng(req.params.cnpj, { nomeOng, email, telefone });
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json(resultado);
});

app.get('/servicos', async (req, res) => res.json(await db.getServicos()));


// ── Cadastro de Serviço da ONG ──
app.post('/servicos/ong', uploadServico.single('imagem'), async (req, res) => {
  try {
    const { nomeServico, descricao, foco, duracao, cnpj } = req.body;

    if (!nomeServico || !descricao || !foco || !duracao || !cnpj) {
      return res.status(400).json({ erro: 'Preencha todos os campos obrigatórios.' });
    }

    // ── Checagem do limite de serviços por plano ──
    const premium = await db.isOngPremium(cnpj);
    const limite = premium ? 8 : 5;
    const totalAtual = await db.contarServicosAtivosOng(cnpj);

    if (totalAtual >= limite) {
      return res.status(403).json({
        erro: premium
          ? `Você atingiu o limite de ${limite} serviços do plano Premium.`
          : `Você atingiu o limite de ${limite} serviços do plano gratuito. Assine o Premium para cadastrar até 8 serviços.`
      });
    }

    const imagem = req.file ? req.file.filename : null;

    const id = await db.cadastrarServicoOng({
      nomeServico,
      cnpj,
      horas: duracao,
      descricao,
      foco,
      imagem
    });

    res.json({
      sucesso: true,
      id,
      imagem: imagem ? `/uploads/servicos/${imagem}` : null
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
    const { nomeServico, descricao, foco, duracao } = req.body;

    if (!nomeServico || !descricao || !foco || !duracao) {
      return res.status(400).json({ erro: 'Preencha todos os campos obrigatórios.' });
    }

    const imagem = req.file ? req.file.filename : null;

    await db.atualizarServico(req.params.id, {
      nomeServico,
      descricao,
      foco,
      duracao,
      imagem
    });

    res.json({ sucesso: true });
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
  const { nomeServico, descricao, foco, duracao } = req.body;
  if (!nomeServico || !descricao || !foco || !duracao) {
    return res.status(400).json({ erro: 'Preencha todos os campos obrigatórios.' });
  }
  const imagem = req.file ? req.file.filename : null;
  const resultado = await db.atualizarServicoOng(req.params.id, { nomeServico, descricao, foco, horas: duracao, imagem });
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json({ sucesso: true });
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
app.get('/solicitacoes', async (req, res) => res.json(await db.getSolicitacoes()));
app.put('/solicitacoes/:cod', async (req, res) => {
    const { statusS, statusE, pontos } = req.body;
    res.json(await db.alterSolicitacao(req.params.cod, statusS, statusE, pontos));
});

// ── Rotas Premium ──
app.get('/premium',            async (req, res) => res.json(await db.getPremium()));
app.get('/stats/premium-total',async (req, res) => res.json(await db.countPremiumTotal()));
app.get('/stats/atrasadas',    async (req, res) => res.json(await db.countAtrasadas()));
app.get('/stats/receita',      async (req, res) => res.json(await db.countReceita()));

// ── Rotas de Administrador ──
app.put('/adm/login',    async (req, res) => { const { loginAntigo, novoLogin } = req.body; res.json(await db.alterarLoginAdm(loginAntigo, novoLogin)); });
app.put('/adm/senha',    async (req, res) => { const { login, senhaAtual, novaSenha } = req.body; res.json(await db.alterarSenhaAdm(login, senhaAtual, novaSenha)); });
app.post('/adm/cadastrar',async (req, res) => { const { novoLogin, novaSenha } = req.body; res.json(await db.cadastrarAdm(novoLogin, novaSenha)); });

// ── Rotas de Estatísticas ──
app.get('/stats/:tipo', async (req, res) => {
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
  if (!cpf)      return res.status(400).json({ erro: 'CPF não informado' });
  if (!req.file) return res.status(400).json({ erro: 'Nenhum arquivo enviado' });

  const resultado = await db.atualizarFotoPerfil(cpf, req.file.filename);
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
  if (!cnpj)     return res.status(400).json({ erro: 'CNPJ não informado' });
  if (!req.file) return res.status(400).json({ erro: 'Nenhum arquivo enviado' });

  const resultado = await db.atualizarFotoPerfilOng(cnpj, req.file.filename);
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
//const fs = require('fs');

app.get('/certificados/:cpf/:codSolicitacao/pdf', async (req, res) => {
  try {
    const dados = await db.buscarDadosCertificado(req.params.cpf, req.params.codSolicitacao);

    if (!dados) {
      return res.status(404).json({ erro: 'Certificado não encontrado.' });
    }

    let html = fs.readFileSync(path.join(__dirname, 'templates', 'certificado.html'), 'utf8');

    const dataFormatada = new Date(dados.dataConclusao || dados.dataSolicitacao).toLocaleDateString('pt-BR');

    html = html
      .replaceAll('{{nomeUsuario}}', dados.nomeUsuario)
      .replaceAll('{{nomeServico}}', dados.nomeServico)
      .replaceAll('{{nomeOng}}', dados.nomeOng)
      .replaceAll('{{horas}}', dados.horas)
      .replaceAll('{{dataConclusao}}', dataFormatada)
      .replaceAll('{{codigoVerificacao}}', dados.codigoVerificacao); 

    const browser = await puppeteer.launch();
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
  res.json(await db.alterSolicitacaoOng(req.params.cod, statusS, statusE, pontos));
});

// ── Rota de Contato ──
app.post('/contato', async (req, res) => {
  const { nome, email, mensagem } = req.body;

  if (!nome || !email || !mensagem) {
    return res.status(400).json({ sucesso: false, erro: 'Preencha todos os campos.' });
  }

  try {
    await transporter.sendMail({
      from: `"Site Mútuo" <${process.env.EMAIL_USER}>`,
      to: 'mutuo.pi@gmail.com',
      replyTo: email,
      subject: 'Nova mensagem - Contato Mútuo',
      html: `
        <h3>Nova mensagem pelo formulário de contato</h3>
        <p><strong>Nome:</strong> ${nome}</p>
        <p><strong>E-mail:</strong> ${email}</p>
        <p><strong>Mensagem:</strong></p>
        <p>${mensagem.replace(/\n/g, '<br>')}</p>
      `
    });

    res.json({ sucesso: true });
  } catch (erro) {
    console.error('Erro ao enviar e-mail:', erro.message);
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
    const { nomeServico, descricao, foco, duracao, cpf } = req.body;

    if (!nomeServico || !descricao || !foco || !duracao || !cpf) {
      return res.status(400).json({ erro: 'Preencha todos os campos obrigatórios.' });
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

    const id = await db.cadastrarServico({
      nomeServico,
      descricao,
      foco,
      duracao,
      cpf,
      imagem
    });

    res.json({
      sucesso: true,
      id,
      imagem: imagem ? `/uploads/servicos/${imagem}` : null
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

// confirmação e avaliação

app.put('/solicitacoes/:cod', async (req, res) => {
  const { statusS, statusE } = req.body;
  const resultado = await db.responderSolicitacao(req.params.cod, statusS, statusE);
  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json(resultado);
});

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


// Garante que qualquer erro (ex: multer rejeitando arquivo, tamanho excedido,
// campo com nome errado) sempre responda em JSON, nunca em HTML.
// Precisa ficar DEPOIS de todas as rotas, senão erros lançados nelas não são capturados.
app.use((err, req, res, next) => {
  console.error('Erro capturado pelo middleware global:', err.message);
  res.status(400).json({ erro: err.message || 'Erro ao processar a requisição.' });
});


const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`API rodando na porta ${PORT}`));