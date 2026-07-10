const express = require('express');
const cors    = require('cors');
const path    = require('path');
const multer  = require('multer');
const fs      = require('fs');
const db      = require('./db');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json({ limit: '20mb' }));
app.use(express.urlencoded({ extended: true, limit: '20mb' }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

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
    // Aceita tanto cpf (usuário comum) quanto cnpj (ONG) como identificador do arquivo
    const id = req.body?.cnpj || req.body?.cpf || 'sem-id';
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
app.put('/usuarios/:cpf', async (req, res) => {
    const { ativo, pontos, horas } = req.body;
    res.json(await db.alterUsuario(req.params.cpf, ativo, pontos, horas));
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
app.get('/ongs/:cnpj', async (req, res) => {
  const ong = await db.getOngPorCnpj(req.params.cnpj);
  if (!ong) return res.status(404).json({ erro: 'ONG não encontrada' });
  if (ong.error) return res.status(500).json({ erro: ong.error });
  res.json(ong);
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
app.put('/servicos/:cod', async (req, res) => {
    const cod = decodeURIComponent(req.params.cod);
    const { ativo, horas, foco, nota } = req.body;
    res.json(await db.alterServico(cod, ativo, horas, foco, nota));
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
  console.log('📸 CPF recebido:', req.body.cpf);
  console.log('📁 Arquivo recebido:', req.file);

  const cpf = req.body.cpf;
  if (!cpf)      return res.status(400).json({ erro: 'CPF não informado' });
  if (!req.file) return res.status(400).json({ erro: 'Nenhum arquivo enviado' });

  const resultado = await db.atualizarFotoPerfil(cpf, req.file.filename);
  console.log('💾 Resultado do banco:', resultado);

  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json({ sucesso: true, fotoPerfil: `/uploads/fotos/${req.file.filename}` });
});

app.get('/perfil/foto/:cpf', async (req, res) => {
  const foto = await db.getFotoPerfil(req.params.cpf);
  res.json({ fotoPerfil: foto ? `/uploads/fotos/${foto}` : null });
});

// ── Foto de Perfil (ONG) ──
app.post('/perfil/foto/ong', upload.single('fotoPerfil'), async (req, res) => {
  console.log('📸 CNPJ recebido:', req.body.cnpj);
  console.log('📁 Arquivo recebido:', req.file);

  const cnpj = req.body.cnpj;
  if (!cnpj)     return res.status(400).json({ erro: 'CNPJ não informado' });
  if (!req.file) return res.status(400).json({ erro: 'Nenhum arquivo enviado' });

  const resultado = await db.atualizarFotoPerfilOng(cnpj, req.file.filename);
  console.log('💾 Resultado do banco:', resultado);

  if (resultado.error) return res.status(500).json({ erro: resultado.error });
  res.json({ sucesso: true, fotoPerfil: `/uploads/fotos/${req.file.filename}` });
});

app.get('/perfil/foto/ong/:cnpj', async (req, res) => {
  const foto = await db.getFotoPerfilOng(req.params.cnpj);
  res.json({ fotoPerfil: foto ? `/uploads/fotos/${foto}` : null });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`API rodando na porta ${PORT}`));