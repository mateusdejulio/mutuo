const express = require('express');
const cors = require('cors');
const db = require('./db');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Rotas de Autenticação
app.post('/login', async (req, res) => {
    const { login, senha } = req.body;
    const result = await db.validarLogin(login, senha);
    res.json(result);
});

app.post('/loginUsuario', async (req, res) => {
  const { email, senha } = req.body;
 
  if (!email || !senha) {
    return res.status(400).json({ sucesso: false, mensagem: 'Email e senha são obrigatórios' });
  }
 
  try {
    const resultado = await db.validarLoginUsuario(email, senha);
    return res.json(resultado);
  } catch (error) {
    console.error(error);
    return res.status(500).json({ sucesso: false, mensagem: 'Erro interno do servidor' });
  }
});
 
app.post('/loginOng', async (req, res) => {
  const { email, senha } = req.body;
 
  if (!email || !senha) {
    return res.status(400).json({ sucesso: false, mensagem: 'Email e senha são obrigatórios' });
  }
 
  try {
    const resultado = await db.validarLoginOng(email, senha);
    return res.json(resultado);
  } catch (error) {
    console.error(error);
    return res.status(500).json({ sucesso: false, mensagem: 'Erro interno do servidor' });
  }
});

// Rotas de Usuários
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

// Rotas de ONGs e Serviços
app.get('/ongs', async (req, res) => res.json(await db.getONGs()));
app.post('/ongs', async (req, res) => {
    try {
        const id = await db.cadastrarOng(req.body);
        res.json({ sucesso: true, id });
    } catch (e) { res.status(500).json({ sucesso: false, erro: e.message }); }
});
app.put('/ongs/:cnpj', async (req, res) => {
    const { ativo, responsavel, foco } = req.body;
    res.json(await db.alterONG(req.params.cnpj, ativo, responsavel, foco));
});
app.get('/servicos', async (req, res) => res.json(await db.getServicos()));
app.put('/servicos/:cod', async (req, res) => {
    const cod = decodeURIComponent(req.params.cod);
    const { ativo, horas, foco, nota } = req.body;
    res.json(await db.alterServico(cod, ativo, horas, foco, nota));
});

// Rotas de Solicitações
app.get('/solicitacoes', async (req, res) => res.json(await db.getSolicitacoes()));
app.put('/solicitacoes/:cod', async (req, res) => {
    const { statusS, statusE, pontos } = req.body;
    res.json(await db.alterSolicitacao(req.params.cod, statusS, statusE, pontos));
});

//Rotas Premium
app.get('/premium', async (req, res) => res.json(await db.getPremium()));

app.get('/stats/premium-total', async (req, res) => res.json(await db.countPremiumTotal()));

app.get('/stats/atrasadas', async (req, res) => res.json(await db.countAtrasadas()));

app.get('/stats/receita', async (req, res) => res.json(await db.countReceita()));

// Rotas de Administrador
app.put('/adm/login', async (req, res) => {
    const { loginAntigo, novoLogin } = req.body;
    res.json(await db.alterarLoginAdm(loginAntigo, novoLogin));
});

app.put('/adm/senha', async (req, res) => {
    const { login, senhaAtual, novaSenha } = req.body;
    res.json(await db.alterarSenhaAdm(login, senhaAtual, novaSenha));
});

app.post('/adm/cadastrar', async (req, res) => {
    const { novoLogin, novaSenha } = req.body;
    res.json(await db.cadastrarAdm(novoLogin, novaSenha));
});


// Rotas de Estatísticas (Dashboard)
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

//foto de perfil
const multer = require('multer');
const path = require('path');
const { atualizarFotoPerfil, getFotoPerfil } = require('./db');

// Configuração do multer — salva em /uploads/fotos/
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, path.join(__dirname, 'public', 'uploads', 'fotos'));
  },
  filename: (req, file, cb) => {
    // Nome único: cpf + timestamp + extensão original
    const cpf = req.session?.usuario?.cpf || 'sem-cpf';
    const ext = path.extname(file.originalname);
    cb(null, `${cpf}-${Date.now()}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 3 * 1024 * 1024 }, // 3 MB
  fileFilter: (req, file, cb) => {
    const tipos = ['image/jpeg', 'image/png', 'image/webp'];
    if (tipos.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Apenas imagens JPG, PNG ou WEBP são aceitas.'));
  }
});

// POST /perfil/foto — recebe o upload
app.post('/perfil/foto', upload.single('fotoPerfil'), async (req, res) => {
  const cpf = req.body.cpf;
  if (!cpf)      return res.status(400).json({ erro: 'CPF não informado' });
  if (!req.file) return res.status(400).json({ erro: 'Nenhum arquivo enviado' });

  const resultado = await db.atualizarFotoPerfil(cpf, req.file.filename);
  if (resultado.error) return res.status(500).json({ erro: resultado.error });

  res.json({ sucesso: true, fotoPerfil: `/uploads/fotos/${req.file.filename}` });
});

app.get('/perfil/foto/:cpf', async (req, res) => {
  const foto = await db.getFotoPerfil(req.params.cpf);
  res.json({ fotoPerfil: foto ? `/uploads/fotos/${foto}` : null });
});
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`API rodando na porta ${PORT}`));