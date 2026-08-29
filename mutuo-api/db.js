const mysql = require('mysql2/promise');
const path = require('path');
const bcrypt = require('bcryptjs');

require('dotenv').config({ path: path.resolve(__dirname, '.env') });

console.log("Tentando conectar ao banco:", process.env.DB_HOST);

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: '-03:00' // NOW() do banco grava em horário de Brasília; sem isso
                      // o mysql2 interpreta o valor cru como UTC e desalinha
                      // todos os horários em -3h ao converter pro front-end.
});

// Garante que o campo "foco" seja sempre salvo em minúsculo e sem espaços
// nas pontas, independente do valor recebido do client (app, web etc).
function normalizarFoco(foco) {
  return foco ? foco.trim().toLowerCase() : foco;
}

async function validarLogin(login, senha) {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM Mutuo_Adm WHERE login = ? AND senha = ?',
      [login, senha]
    );
    return rows.length > 0; // Retorna true ou false
  } catch (error) {
    console.error('Erro ao validar administrador:', error);
    return false; // Retorna false se o banco der erro
  }
}



async function validarLoginUsuario(email, senha) {
  try {
    const [rows] = await pool.query(
      'SELECT cpf, nome, email, telefone, cidade, estado, pontos, horasVoluntarias, cadastro, senha FROM Mutuo_Usuario WHERE email = ? AND ativo = 1',
      [email]
    );

    if (rows.length === 0) {
      return { sucesso: false, mensagem: 'Email ou senha incorretos, ou conta inativa.' };
    }

    const usuario = rows[0];
    const senhaValida = await verificarSenha(senha, usuario.senha, 'Mutuo_Usuario', 'cpf', usuario.cpf);

    if (!senhaValida) {
      return { sucesso: false, mensagem: 'Email ou senha incorretos, ou conta inativa.' };
    }

    delete usuario.senha; // nunca devolve a senha/hash pro front-end
    return { sucesso: true, usuario };

  } catch (error) {
    console.error('Erro ao validar usuário:', error);
    return { sucesso: false, mensagem: 'Erro interno ao validar login.' };
  }
}

async function validarLoginOng(email, senha) {
  try {
    const [rows] = await pool.query(
      'SELECT cnpj, nomeOng, nomeResponsavel, email, telefone, cidade, estado, foco, premium, cadastro, senha FROM Mutuo_ONG WHERE email = ? AND ativo = 1',
      [email]
    );

    if (rows.length === 0) {
      return { sucesso: false, mensagem: 'Email ou senha incorretos, ou conta inativa.' };
    }

    const ong = rows[0];
    const senhaValida = await verificarSenha(senha, ong.senha, 'Mutuo_ONG', 'cnpj', ong.cnpj);

    if (!senhaValida) {
      return { sucesso: false, mensagem: 'Email ou senha incorretos, ou conta inativa.' };
    }

    delete ong.senha; // nunca devolve a senha/hash pro front-end
    return { sucesso: true, usuario: ong };
  } catch (error) {
    console.error('Erro ao validar ONG:', error);
    return { sucesso: false, mensagem: 'Erro interno ao validar login.' };
  }
}

// Compara a senha digitada com a armazenada. Se a senha no banco ainda
// estiver em texto puro (usuários antigos), compara direto e já migra
// para hash bcrypt automaticamente, sem precisar de script manual.
async function verificarSenha(senhaDigitada, senhaArmazenada, tabela, colunaId, idValor) {
  const pareceHash = typeof senhaArmazenada === 'string' && senhaArmazenada.startsWith('$2');

  if (pareceHash) {
    return bcrypt.compare(senhaDigitada, senhaArmazenada);
  }

  // Senha antiga em texto puro
  if (senhaDigitada === senhaArmazenada) {
    const novoHash = await bcrypt.hash(senhaDigitada, 10);
    await pool.query(`UPDATE ${tabela} SET senha = ? WHERE ${colunaId} = ?`, [novoHash, idValor]);
    return true;
  }

  return false;
}



async function getUsuarios() {
  const [rows] = await pool.query('SELECT cpf, nome, email, ativo, pontos, horasVoluntarias, cadastro FROM Mutuo_Usuario');
  return rows;
}

// Busca os dados completos de UM usuário específico pelo CPF (usado na tela de perfil)
async function getUsuarioPorCpf(cpf) {
  try {
    const [rows] = await pool.query('SELECT * FROM Mutuo_Usuario WHERE cpf = ?', [cpf]);
    if (rows.length === 0) return null;

    // nunca devolve a senha pro front-end
    const usuario = rows[0];
    delete usuario.senha;
    return usuario;
  } catch (err) {
    console.error('Erro ao buscar usuário por cpf:', err.message);
    return { error: err.message };
  }
}

// Atualiza os campos editáveis na tela "Dados do usuário" (nome, email, telefone)
async function atualizarDadosUsuario(cpf, { nome, email, telefone }) {
  try {
    const [result] = await pool.query(
      'UPDATE Mutuo_Usuario SET nome = ?, email = ?, telefone = ? WHERE cpf = ?',
      [nome, email, telefone, cpf]
    );
    return { success: result.affectedRows > 0 };
  } catch (err) {
    console.error('Erro ao atualizar dados do usuário:', err.message);
    return { error: err.message };
  }
}

async function getONGs() {
  const [rows] = await pool.query('SELECT cnpj, nomeOng, nomeResponsavel, email, foco, ativo, premium FROM Mutuo_ONG');
  return rows;
}

async function getServicos() {
  const [rows] = await pool.query('SELECT s.cod, s.nome, s.foco, s.qtdHoras, s.ativo, s.avaliacao, s.idUsuario, u.nome AS nomeCriador FROM Mutuo_Servico AS s JOIN Mutuo_Usuario AS u ON s.idUsuario = u.cpf');
  return rows;
}

async function getSolicitacoes() {
  const sql = `
    SELECT 
      SOL.codSolicitacao,
      SOL.statusSolicitacao,
      SOL.statusExecucao,
      SOL.dataSolicitacao,
      SOL.dataConclusao,
      SOL.pontos,
      
      SERV.nome AS nomeServico,
      
      USOL.nome AS nomeSolicitador,
      
      UPRES.nome AS nomePrestador
      
    FROM 
      Mutuo_Solicitacao AS SOL

    JOIN Mutuo_Servico AS SERV 
      ON SOL.codServico = SERV.cod

    JOIN Mutuo_Usuario AS USOL 
      ON SOL.codUsuario = USOL.cpf

    JOIN Mutuo_Usuario AS UPRES 
      ON SERV.idUsuario = UPRES.cpf
  `;

  try {
    const [rows] = await pool.query(sql);
    return rows;
  } catch (err) {
    console.error("Erro no db.js/getSolicitacoes:", err.message);
    return { error: err.message };
  }
}

async function countUsuarios() {
  const [rows] = await pool.query('SELECT COUNT(*) AS total FROM Mutuo_Usuario WHERE ativo = 1');
  return rows[0].total;
}

async function countONGs() {
  const [rows] = await pool.query('SELECT COUNT(*) AS total FROM Mutuo_ONG WHERE ativo = 1');
  return rows[0].total;
}

async function countServicos() {
  const [rows] = await pool.query('SELECT SUM(realizado) AS total FROM Mutuo_Servico');
  return rows[0].total;
}

async function countHoras() {
  const [rows] = await pool.query('SELECT SUM(horasVoluntarias) AS total FROM Mutuo_Usuario');
  return rows[0].total;
}

async function countUsuariosInativos() {
  const [rows] = await pool.query('SELECT COUNT(*) AS total FROM Mutuo_Usuario WHERE ativo = 0');
  return rows[0].total;
}

async function countPontos() {
  const [rows] = await pool.query('SELECT SUM(pontos) AS total FROM Mutuo_Usuario');
  return rows[0].total;
}

async function countONGsInativas() {
  const [rows] = await pool.query('SELECT COUNT(*) AS total FROM Mutuo_ONG WHERE ativo = 0');
  return rows[0].total;
}

async function countPremium() {
  const [rows] = await pool.query('SELECT SUM(premium) AS total FROM Mutuo_ONG');
  return rows[0].total;
}

async function countServicosCadastrados() {
  const [rows] = await pool.query('SELECT COUNT(*) AS total FROM Mutuo_Servico WHERE ativo = 1');
  return rows[0].total;
}

async function countSolicitacoesAceitas() {
  const [rows] = await pool.query('SELECT COUNT(*) AS total FROM Mutuo_Solicitacao WHERE statusSolicitacao = "Aceita"');
  return rows[0].total;
}

async function countSolicitacoesPendentes() {
  const [rows] = await pool.query('SELECT COUNT(*) AS total FROM Mutuo_Solicitacao WHERE statusSolicitacao = "Pendente"');
  return rows[0].total;
}

async function countSolicitacoesRecusadas() {
  const [rows] = await pool.query('SELECT COUNT(*) AS total FROM Mutuo_Solicitacao WHERE statusSolicitacao = "Recusada"');
  return rows[0].total;
}

async function alterUsuario(cpf, ativo, pontos, horas) {
  const sql = 'UPDATE Mutuo_Usuario SET ativo = ?, pontos = ?, horasVoluntarias = ? WHERE cpf = ?';

  try {
    const [result] = await pool.query(sql, [ativo, pontos, horas, cpf]);
    return { success: true, affectedRows: result.affectedRows };
  } catch (err) {
    console.error("Erro no db.js/alterUsuario:", err.message);
    return { error: err.message };
  }
}

async function alterONG(cnpj, ativo, responsavel, foco) {
  const sql = 'UPDATE Mutuo_ONG SET ativo = ?, nomeResponsavel = ?, foco = ? WHERE cnpj = ?';

  try {
    const [result] = await pool.query(sql, [ativo, responsavel, normalizarFoco(foco), cnpj]);
    return { success: true, affectedRows: result.affectedRows };
  } catch (err) {
    console.error("Erro no db.js/alterONG:", err.message);
    return { error: err.message };
  }
}

async function mediaNotas() {
  const [rows] = await pool.query('SELECT AVG(avaliacao) AS total FROM Mutuo_Servico');
  return rows[0].total;
}

async function alterServico(cod, ativo, horas, foco, nota) {
  const sql = 'UPDATE Mutuo_Servico SET ativo = ?, qtdHoras = ?, foco = ?, avaliacao = ? WHERE cod = ?';

  try {
    const [result] = await pool.query(sql, [ativo, horas, normalizarFoco(foco), nota, cod]);
    return { success: true, affectedRows: result.affectedRows };
  } catch (err) {
    console.error("Erro no db.js/alterServico:", err.message);
    return { error: err.message };
  }
}

// no db.js
async function alterSolicitacao(cod, statusS, statusE, pontos) {
  try {
    await pool.query(
      `UPDATE Mutuo_Solicitacao SET statusSolicitacao = ?, statusExecucao = ?, pontos = ?, lida = 1 WHERE codSolicitacao = ?`,
      [statusS, statusE, pontos, cod]
    );
    return { sucesso: true };
  } catch (err) {
    console.error('Erro ao alterar solicitação:', err.message);
    return { error: err.message };
  }
}
//cadastros

async function cadastrarUsuario(usuario) {
  const sql = `
    INSERT INTO Mutuo_Usuario
    (cpf, nome, email, senha, telefone, cidade, bairro, cep, dataNasc, pontos, horasVoluntarias, estado, endereco, cadastro)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 20, 0, ?, ?, ?)
  `;

  const senhaHash = await bcrypt.hash(usuario.senha, 10);

  const values = [
    usuario.cpf,
    usuario.nome,
    usuario.email,
    senhaHash,
    usuario.telefone,
    usuario.cidade,
    usuario.bairro,
    usuario.cep,
    usuario.nascimento,
    usuario.uf,
    usuario.endereco,
    usuario.cadastro,
  ];

  try {
    const [result] = await pool.query(sql, values);
    return result.insertId;
  } catch (error) {
    console.error('Erro ao cadastrar usuário:', error);
    throw error;
  }
}

async function cadastrarOng(ong) {
  const sql = `
    INSERT INTO Mutuo_ONG
    (nomeOng, cnpj, email, nomeResponsavel, telefone, cidade, bairro, endereco, estado, senha, foco, descricao, foto_perfil, cadastro, pontos)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,?,?,0)
  `;

  const senhaHash = await bcrypt.hash(ong.senha, 10);

  const values = [
    ong.nomeOng,
    ong.cnpj,
    ong.email,
    ong.nomeResponsavel,
    ong.telefone,
    ong.cidade,
    ong.bairro,
    ong.endereco,
    ong.uf,
    senhaHash,
    normalizarFoco(ong.foco),
    ong.descricao,
    ong.foto_perfil,
    ong.cadastro
  ];

  try {
    const [result] = await pool.query(sql, values);
    return result.insertId;
  } catch (error) {
    console.error('Erro ao cadastrar ong:', error);
    throw error;
  }
}

// ── Cadastro de serviço oferecido por usuário ──
async function cadastrarServico(servico) {
  const sql = `
    INSERT INTO Mutuo_Servico
    (nome, descricao, foco, qtdHoras, idUsuario, imagem)
    VALUES (?, ?, ?, ?, ?, ?)
  `;

  const values = [
    servico.nomeServico,
    servico.descricao,
    normalizarFoco(servico.foco),
    servico.duracao,
    servico.cpf,
    servico.imagem
  ];

  try {
    const [result] = await pool.query(sql, values);
    return result.insertId;
  } catch (error) {
    console.error('Erro ao cadastrar serviço:', error);
    throw error;
  }
}

// ── Cadastro de serviço oferecido pela ONG ──
async function cadastrarServicoOng(servico) {
  const sql = `
    INSERT INTO Mutuo_ServicoOng
    (nomeServico, cnpj, horas, descricao, foco, imagem)
    VALUES (?, ?, ?, ?, ?, ?)
  `;

  const values = [
    servico.nomeServico,
    servico.cnpj,
    servico.horas,
    servico.descricao,
    normalizarFoco(servico.foco),
    servico.imagem
  ];

  try {
    const [result] = await pool.query(sql, values);
    return result.insertId;
  } catch (error) {
    console.error('Erro ao cadastrar serviço da ONG:', error);
    throw error;
  }
}

// Lista os serviços cadastrados por um usuário comum
async function getServicosUsuario(cpf) {
  try {
    const [rows] = await pool.query(
      `SELECT cod AS id, nome AS nomeServico, descricao, foco, qtdHoras AS horas, imagem, ativo
       FROM Mutuo_Servico
       WHERE idUsuario = ? AND ativo = 1`,
      [cpf]
    );
    return rows.map(servico => ({
      ...servico,
      imagem: servico.imagem ? `/uploads/servicos/${servico.imagem}` : null
    }));
  } catch (err) {
    console.error('Erro ao buscar serviços do usuário:', err.message);
    return { error: err.message };
  }
}

// Ativa/desativa um serviço de usuário
async function atualizarStatusServico(id, ativo) {
  const [result] = await pool.query(
    'UPDATE Mutuo_Servico SET ativo = ? WHERE cod = ?',
    [ativo, id]
  );
  return result.affectedRows;
}

// Busca um serviço específico do usuário pelo ID
async function getServicoPorId(id) {
  try {
    const [rows] = await pool.query(
      `SELECT cod AS id, nome AS nomeServico, descricao, foco, qtdHoras AS duracao, imagem, idUsuario
       FROM Mutuo_Servico
       WHERE cod = ?`,
      [id]
    );
    return rows[0] || null;
  } catch (err) {
    console.error('Erro ao buscar serviço:', err.message);
    return { error: err.message };
  }
}

// Atualiza um serviço do usuário
async function atualizarServico(id, servico) {
  const campos = ['nome = ?', 'descricao = ?', 'foco = ?', 'qtdHoras = ?'];
  const valores = [servico.nomeServico, servico.descricao, normalizarFoco(servico.foco), servico.duracao];

  if (servico.imagem) {
    campos.push('imagem = ?');
    valores.push(servico.imagem);
  }

  valores.push(id);

  const sql = `UPDATE Mutuo_Servico SET ${campos.join(', ')} WHERE cod = ?`;

  try {
    const [result] = await pool.query(sql, valores);
    return result.affectedRows;
  } catch (error) {
    console.error('Erro ao atualizar serviço:', error);
    throw error;
  }
}

// Lista os serviços cadastrados por uma ONG específica
async function getServicosOng(cnpj) {
  try {
    const [rows] = await pool.query(
      'SELECT id, nomeServico, cnpj, horas, descricao, foco, imagem FROM Mutuo_ServicoOng WHERE cnpj = ? AND ativo = 1',
      [cnpj]
    );
    return rows.map(servico => ({
      ...servico,
      imagem: servico.imagem ? `/uploads/servicos/${servico.imagem}` : null
    }));
  } catch (err) {
    console.error('Erro ao buscar serviços da ONG:', err.message);
    return { error: err.message };
  }
}

async function getPremium() {
  try {
    const [ongs] = await pool.query('SELECT id, cnpj, statusPag, qtdPag, "ONG" as tipo FROM Mutuo_ONGPremium');
    const [usuarios] = await pool.query('SELECT id, cpf, statusPag, qtdPag, "USUARIO" as tipo FROM Mutuo_UsuarioPremium');

    return [...ongs, ...usuarios];
  } catch (err) {
    console.error("Erro ao buscar premium:", err.message);
    return { error: err.message };
  }
}

async function countPremiumTotal() {
  try {
    const [ongs] = await pool.query('SELECT COUNT(*) as total FROM Mutuo_ONGPremium');
    const [usuarios] = await pool.query('SELECT COUNT(*) as total FROM Mutuo_UsuarioPremium');

    return ongs[0].total + usuarios[0].total;
  } catch (err) {
    console.error("Erro ao contar premium:", err.message);
    return 0;
  }
}

async function countAtrasadas() {
  try {
    const [ongs] = await pool.query('SELECT COUNT(*) as total FROM Mutuo_ONGPremium WHERE statusPag = 0');
    const [usuarios] = await pool.query('SELECT COUNT(*) as total FROM Mutuo_UsuarioPremium WHERE statusPag = 0');

    return ongs[0].total + usuarios[0].total;
  } catch (err) {
    console.error("Erro ao contar atrasadas:", err.message);
    return 0;
  }
}

async function countReceita() {
  try {
    const [ongs] = await pool.query('SELECT SUM(qtdPag) as total FROM Mutuo_ONGPremium');
    const [usuarios] = await pool.query('SELECT SUM(qtdPag) as total FROM Mutuo_UsuarioPremium');

    const totalPagamentos = (ongs[0].total || 0) + (usuarios[0].total || 0);

    return totalPagamentos * 25;
  } catch (err) {
    console.error("Erro ao calcular receita:", err.message);
    return 0;
  }
}

async function alterarLoginAdm(loginAntigo, novoLogin) {
  try {
    const [result] = await pool.query(
      'UPDATE Mutuo_Adm SET login = ? WHERE login = ?',
      [novoLogin, loginAntigo]
    );
    return { success: result.affectedRows > 0 };
  } catch (err) {
    console.error("Erro ao alterar login:", err.message);
    return { error: err.message };
  }
}

async function alterarSenhaAdm(login, senhaAtual, novaSenha) {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM Mutuo_Adm WHERE login = ? AND senha = ?',
      [login, senhaAtual]
    );
    if (rows.length === 0) return { error: 'Senha atual incorreta' };

    const [result] = await pool.query(
      'UPDATE Mutuo_Adm SET senha = ? WHERE login = ?',
      [novaSenha, login]
    );
    return { success: result.affectedRows > 0 };
  } catch (err) {
    console.error("Erro ao alterar senha:", err.message);
    return { error: err.message };
  }
}

async function cadastrarAdm(novoLogin, novaSenha) {
  try {
    const [result] = await pool.query(
      'INSERT INTO Mutuo_Adm (login, senha) VALUES (?, ?)',
      [novoLogin, novaSenha]
    );
    return { success: result.affectedRows > 0 };
  } catch (err) {
    console.error("Erro ao cadastrar admin:", err.message);
    return { error: err.message };
  }
}
async function getFotoPerfil(cpf) {
  try {
    const [rows] = await pool.query(
      'SELECT foto_perfil FROM Mutuo_Usuario WHERE cpf = ?',
      [cpf]
    );
    return rows.length > 0 ? rows[0].foto_perfil : null;
  } catch (err) {
    console.error('Erro ao buscar foto:', err.message);
    return null;
  }
}

async function atualizarFotoPerfil(cpf, nomeArquivo) {
  try {
    const [result] = await pool.query(
      'UPDATE Mutuo_Usuario SET foto_perfil = ? WHERE cpf = ?',
      [nomeArquivo, cpf]
    );
    return { success: result.affectedRows > 0 };
  } catch (err) {
    console.error('Erro ao atualizar foto:', err.message);
    return { error: err.message };
  }
}

// Buscar dados completos da ONG pelo CNPJ (perfil)
async function getOngPorCnpj(cnpj) {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM Mutuo_ONG WHERE cnpj = ?',
      [cnpj]
    );

    if (rows.length === 0) return null;

    // Nunca devolve a senha para o front-end
    const ong = rows[0];
    delete ong.senha;

    return ong;
  } catch (err) {
    console.error(
      'Erro ao buscar ONG por CNPJ:',
      err.message
    );

    return {
      error: err.message
    };
  }
}

async function getFotoPerfilOng(cnpj) {
  try {
    const [rows] = await pool.query('SELECT foto_perfil FROM Mutuo_ONG WHERE cnpj = ?', [cnpj]);
    return rows.length > 0 ? rows[0].foto_perfil : null;
  } catch (err) {
    console.error('Erro ao buscar foto da ONG:', err.message);
    return null;
  }
}

async function atualizarFotoPerfilOng(cnpj, nomeArquivo) {
  try {
    const [result] = await pool.query(
      'UPDATE Mutuo_ONG SET foto_perfil = ? WHERE cnpj = ?',
      [nomeArquivo, cnpj]
    );
    return { success: result.affectedRows > 0 };
  } catch (err) {
    console.error('Erro ao atualizar foto da ONG:', err.message);
    return { error: err.message };
  }
}

// Atualiza os campos editáveis na tela "Dados do usuário" (nome, email, telefone)
async function atualizarDadosOng(cnpj, { nomeOng, email, telefone }) {
  try {
    const [result] = await pool.query(
      'UPDATE Mutuo_ONG SET nomeOng = ?, email = ?, telefone = ? WHERE cnpj = ?',
      [nomeOng, email, telefone, cnpj]
    );
    return { success: result.affectedRows > 0 };
  } catch (err) {
    console.error('Erro ao atualizar dados da ONG:', err.message);
    return { error: err.message };
  }
}
async function countPontosOng(cnpj) {
  const [rows] = await pool.query(
    'SELECT pontos FROM Mutuo_ONG WHERE cnpj = ?',
    [cnpj]
  );
  return rows[0] ? rows[0].pontos : 0;
}

async function getServicoOngPorId(id) {
  const [rows] = await pool.query(
    'SELECT id, nomeServico, cnpj, horas, descricao, foco, imagem FROM Mutuo_ServicoOng WHERE id = ?',
    [id]
  );
  if (rows.length === 0) return null;
  const servico = rows[0];
  servico.imagem = servico.imagem ? `/uploads/servicos/${servico.imagem}` : null;
  return servico;
}

async function atualizarServicoOng(id, { nomeServico, descricao, foco, horas, imagem }) {
  const campos = ['nomeServico = ?', 'descricao = ?', 'foco = ?', 'horas = ?'];
  const values = [nomeServico, descricao, normalizarFoco(foco), horas];
  if (imagem) { campos.push('imagem = ?'); values.push(imagem); }
  values.push(id);
  const [result] = await pool.query(`UPDATE Mutuo_ServicoOng SET ${campos.join(', ')} WHERE id = ?`, values);
  return { success: result.affectedRows > 0 };
}
// Muda o status "ativo" do serviço da ONG (ativo 1 -> 0)
async function alterarStatusServicoOng(id, ativo) {
  try {
    const [result] = await pool.query(
      'UPDATE Mutuo_ServicoOng SET ativo = ? WHERE id = ?',
      [ativo, id]
    );
    return { success: result.affectedRows > 0 };
  } catch (err) {
    console.error('Erro ao alterar status do serviço da ONG:', err.message);
    return { error: err.message };
  }
}

// Lista todos os serviços de ONGs ativos
async function getServicosOngTodos() {
  const sql = `
    SELECT 
      s.id,
      s.cnpj,
      s.nomeServico,
      s.horas,
      s.descricao,
      s.foco,
      s.imagem,
      s.pontos,
      o.nomeOng,
      o.cidade,
      o.estado,
      o.foto_perfil AS fotoOng
    FROM Mutuo_ServicoOng AS s
    JOIN Mutuo_ONG AS o ON s.cnpj = o.cnpj
    WHERE s.ativo = 1 AND o.ativo = 1
    ORDER BY s.id DESC
  `;
  try {
    const [rows] = await pool.query(sql);
    return rows.map(servico => ({
      ...servico,
      imagem: servico.imagem ? `/uploads/servicos/${servico.imagem}` : null,
      fotoOng: servico.fotoOng ? `/uploads/fotos/${servico.fotoOng}` : null
    }));
  } catch (err) {
    console.error('Erro ao buscar todos os serviços de ONGs:', err.message);
    return { error: err.message };
  }
}

// Lista todos os serviços de usuários ativos
async function getServicosUsuarioTodos() {
  const sql = `
    SELECT 
      s.cod,
      s.nome,
      s.descricao,
      s.foco,
      s.qtdHoras,
      s.imagem,
      s.pontos,
      s.idUsuario,
      u.nome AS nomeUsuario,
      u.cidade,
      u.estado,
      u.foto_perfil AS fotoUsuario
    FROM Mutuo_Servico AS s
    JOIN Mutuo_Usuario AS u ON s.idUsuario = u.cpf
    WHERE s.ativo = 1 AND u.ativo = 1
    ORDER BY s.cod DESC
  `;
  try {
    const [rows] = await pool.query(sql);
    return rows.map(servico => ({
      ...servico,
      imagem: servico.imagem ? `/uploads/servicos/${servico.imagem}` : null,
      fotoUsuario: servico.fotoUsuario ? `/uploads/fotos/${servico.fotoUsuario}` : null
    }));
  } catch (err) {
    console.error('Erro ao buscar todos os serviços de usuários:', err.message);
    return { error: err.message };
  }
}

// Cria uma nova solicitação de um usuário em um serviço
async function cadastrarSolicitacao(codServico, codUsuario, pontos) {
  const sql = `
    INSERT INTO Mutuo_Solicitacao
    (codServico, codUsuario, statusSolicitacao, statusExecucao, dataSolicitacao, pontos)
    VALUES (?, ?, 'Pendente', 'Não iniciado', NOW(), ?)
  `;

  try {
    const [result] = await pool.query(sql, [codServico, codUsuario, pontos]);
    return { success: true, id: result.insertId };
  } catch (err) {
    console.error('Erro ao cadastrar solicitação:', err.message);
    return { error: err.message };
  }
}
// Solicitações que ESTE usuário recebeu (ele é o dono do serviço)
async function getSolicitacoesPrestador(cpfPrestador) {
  const sql = `
    SELECT 
      SOL.codSolicitacao,
      SOL.statusSolicitacao,
      SOL.statusExecucao,
      SOL.dataSolicitacao,
      SOL.pontos,
      SOL.nota,
      SOL.lida,
      SERV.nome AS nomeServico,
      SERV.qtdHoras,
      USOL.nome AS nomeSolicitador,
      USOL.cpf AS cpfSolicitador,
      USOL.foto_perfil AS fotoSolicitador
    FROM Mutuo_Solicitacao AS SOL
    JOIN Mutuo_Servico AS SERV ON SOL.codServico = SERV.cod
    JOIN Mutuo_Usuario AS USOL ON SOL.codUsuario = USOL.cpf
    WHERE SERV.idUsuario = ?
    ORDER BY SOL.dataSolicitacao DESC
  `;
  try {
    const [rows] = await pool.query(sql, [cpfPrestador]);
    return rows.map(r => ({
      ...r,
      fotoSolicitador: r.fotoSolicitador ? `/uploads/fotos/${r.fotoSolicitador}` : null
    }));
  } catch (err) {
    console.error('Erro ao buscar solicitações do prestador:', err.message);
    return { error: err.message };
  }
}

async function getSolicitacoesUsuario(cpfUsuario) {
  const sql = `
    SELECT 
      SOL.codSolicitacao,
      SOL.statusSolicitacao,
      SOL.statusExecucao,
      SOL.dataSolicitacao,
      SOL.pontos,
      SOL.nota,
      SERV.nome AS nomeServico,
      SERV.qtdHoras,
      UPRES.nome AS nomePrestador,
      UPRES.cpf AS cpfPrestador,
      UPRES.foto_perfil AS fotoPrestador
    FROM Mutuo_Solicitacao AS SOL
    JOIN Mutuo_Servico AS SERV ON SOL.codServico = SERV.cod
    JOIN Mutuo_Usuario AS UPRES ON SERV.idUsuario = UPRES.cpf
    WHERE SOL.codUsuario = ?
    ORDER BY SOL.dataSolicitacao DESC
  `;
  try {
    const [rows] = await pool.query(sql, [cpfUsuario]);
    return rows.map(r => ({
      ...r,
      fotoPrestador: r.fotoPrestador ? `/uploads/fotos/${r.fotoPrestador}` : null
    }));
  } catch (err) {
    console.error('Erro ao buscar solicitações do usuário:', err.message);
    return { error: err.message };
  }
}

async function getEstatisticasUsuario(cpf) {
  const sql = `
    SELECT 
      COALESCE(SUM(horas), 0) AS totalHoras,
      COUNT(*) AS trabalhosConcluidos
    FROM (
      SELECT SERV.qtdHoras AS horas
      FROM Mutuo_Solicitacao AS SOL
      JOIN Mutuo_Servico AS SERV ON SOL.codServico = SERV.cod
      WHERE SERV.idUsuario = ? AND SOL.statusExecucao = 'Realizada'

      UNION ALL

      SELECT SO.horas AS horas
      FROM Mutuo_SolicitacaoONG AS SOL
      JOIN Mutuo_ServicoOng AS SO ON SOL.codServico = SO.id
      WHERE SOL.codUsuario = ? AND SOL.statusExecucao = 'Realizada'
    ) AS combinado
  `;

  try {
    const [rows] = await pool.query(sql, [cpf, cpf]);
    return rows[0];
  } catch (err) {
    console.error('Erro ao buscar estatísticas do usuário:', err.message);
    return { error: err.message };
  }
}

// Verifica se o usuário tem plano premium ativo (usado no dashboard).
// Lê direto de Mutuo_Usuario.premium — a mesma coluna usada pelo limite
// de serviços e pela tela de planos — pra dashboard sempre bater com a
// assinatura real (antes lia de uma tabela separada e desatualizada).
async function getPlanoUsuario(cpf) {
  try {
    const [rows] = await pool.query(
      'SELECT premium FROM Mutuo_Usuario WHERE cpf = ?',
      [cpf]
    );
    if (rows.length === 0) return 'Gratuito';
    return rows[0].premium === 1 ? 'Premium' : 'Gratuito';
  } catch (err) {
    console.error('Erro ao buscar plano do usuário:', err.message);
    return 'Gratuito';
  }
}

// Junta tudo que o dashboard da tela inicial do usuário precisa numa chamada só
async function getDashboardUsuario(cpf) {
  console.log('DEBUG getDashboardUsuario recebeu cpf:', cpf);
  try {
    const [usuarioRows] = await pool.query(
      'SELECT pontos FROM Mutuo_Usuario WHERE cpf = ?',
      [cpf]
    );
    console.log('DEBUG usuarioRows encontrado:', usuarioRows);
    if (usuarioRows.length === 0) return { error: 'Usuário não encontrado' };

    const estatisticas = await getEstatisticasUsuario(cpf);
    const plano = await getPlanoUsuario(cpf);

    return {
      horasServico: Number(estatisticas.totalHoras) || 0,
      trabalhosConcluidos: Number(estatisticas.trabalhosConcluidos) || 0,
      pontos: usuarioRows[0].pontos || 0,
      plano,
    };
  } catch (err) {
    console.error('Erro ao montar dashboard do usuário:', err.message);
    return { error: err.message };
  }
}


// Cria solicitação para serviço de ONG
async function cadastrarSolicitacaoOng(codServico, codUsuario, pontos) {
  const sql = `
    INSERT INTO Mutuo_SolicitacaoONG
    (codServico, codUsuario, statusSolicitacao, statusExecucao, dataSolicitacao, pontos)
    VALUES (?, ?, 'Pendente', 'Não iniciado', NOW(), ?)
  `;
  try {
    const [result] = await pool.query(sql, [codServico, codUsuario, pontos]);
    return { success: true, id: result.insertId };
  } catch (err) {
    console.error('Erro ao cadastrar solicitação de ONG:', err.message);
    return { error: err.message };
  }
}
// Lista as solicitações RECEBIDAS por uma ONG (ela é a dona do serviço)
async function getSolicitacoesOng(cnpj) {
  const sql = `
    SELECT
      SOL.codSolicitacao,
      SOL.statusSolicitacao,
      SOL.statusExecucao,
      SOL.dataSolicitacao,
      SOL.pontos,
      SOL.lida,
      SERV.nomeServico,
      USOL.nome AS nomeSolicitador,
      USOL.cpf AS cpfSolicitador,
      USOL.foto_perfil AS fotoSolicitador
    FROM Mutuo_SolicitacaoONG AS SOL
    JOIN Mutuo_ServicoOng AS SERV ON SOL.codServico = SERV.id
    JOIN Mutuo_Usuario AS USOL ON SOL.codUsuario = USOL.cpf
    WHERE SERV.cnpj = ?
    ORDER BY SOL.dataSolicitacao DESC
  `;
  try {
    const [rows] = await pool.query(sql, [cnpj]);
    return rows.map(r => ({
      ...r,
      fotoSolicitador: r.fotoSolicitador ? `/uploads/fotos/${r.fotoSolicitador}` : null
    }));
  } catch (err) {
    console.error('Erro ao buscar solicitações da ONG:', err.message);
    return { error: err.message };
  }
}

// Conta usuários distintos que concluíram serviços pertencentes a uma ONG.
async function contarVoluntariosOng(cnpj) {
  try {
    const [rows] = await pool.query(
      `SELECT COUNT(DISTINCT SOL.codUsuario) AS totalVoluntarios
       FROM Mutuo_SolicitacaoONG AS SOL
       JOIN Mutuo_ServicoOng AS SERV ON SOL.codServico = SERV.id
       WHERE SERV.cnpj = ?
         AND LOWER(TRIM(SOL.statusExecucao)) = 'realizada'`,
      [cnpj]
    );

    return Number(rows[0]?.totalVoluntarios || 0);
  } catch (err) {
    console.error('Erro ao contar voluntários da ONG:', err.message);
    throw err;
  }
}

// Aceita/recusa uma solicitação de serviço de ONG
async function alterSolicitacaoOng(cod, statusS, statusE, pontos) {
  const sql = 'UPDATE Mutuo_SolicitacaoONG SET statusSolicitacao = ?, statusExecucao = ?, pontos = ?, lida = 1 WHERE codSolicitacao = ?';
  try {
    const [result] = await pool.query(sql, [statusS, statusE, pontos, cod]);
    return { success: true, affectedRows: result.affectedRows };
  } catch (err) {
    console.error('Erro ao alterar solicitação da ONG:', err.message);
    return { error: err.message };
  }
}

// Conta solicitações não lidas recebidas por uma ONG (badge de notificações).
async function contarNaoLidasOng(cnpj) {
  try {
    const [[resultado]] = await pool.query(
      `SELECT COUNT(*) AS total
       FROM Mutuo_SolicitacaoONG SOL
       JOIN Mutuo_ServicoOng SERV ON SOL.codServico = SERV.id
       WHERE SERV.cnpj = ? AND SOL.lida = 0`,
      [cnpj]
    );
    return resultado.total;
  } catch (err) {
    console.error('Erro ao contar não lidas da ONG:', err.message);
    return { error: err.message };
  }
}

async function marcarSolicitacaoOngLida(cod) {
  try {
    await pool.query(`UPDATE Mutuo_SolicitacaoONG SET lida = 1 WHERE codSolicitacao = ?`, [cod]);
    return { sucesso: true };
  } catch (err) {
    console.error('Erro ao marcar solicitação da ONG como lida:', err.message);
    return { error: err.message };
  }
}

// Dados mínimos de uma solicitação (usuário-prestador) pra montar a
// notificação de aceite/recusa pro solicitador.
async function getSolicitacaoBasica(cod) {
  try {
    const [[row]] = await pool.query(
      `SELECT SOL.codUsuario, SERV.nome AS nomeServico
       FROM Mutuo_Solicitacao SOL
       JOIN Mutuo_Servico SERV ON SOL.codServico = SERV.cod
       WHERE SOL.codSolicitacao = ?`,
      [cod]
    );
    return row || null;
  } catch (err) {
    console.error('Erro ao buscar solicitação:', err.message);
    return null;
  }
}

// Idem, pro lado ONG (Mutuo_SolicitacaoONG + Mutuo_ServicoOng).
async function getSolicitacaoOngBasica(cod) {
  try {
    const [[row]] = await pool.query(
      `SELECT SOL.codUsuario, SERV.nomeServico
       FROM Mutuo_SolicitacaoONG SOL
       JOIN Mutuo_ServicoOng SERV ON SOL.codServico = SERV.id
       WHERE SOL.codSolicitacao = ?`,
      [cod]
    );
    return row || null;
  } catch (err) {
    console.error('Erro ao buscar solicitação da ONG:', err.message);
    return null;
  }
}

async function buscarCertificadosPorUsuario(cpf) {
  const [servicos] = await pool.query(
    `SELECT 
       sol.codSolicitacao,
       sol.pontos          AS pontosSolicitacao,
       sol.dataSolicitacao,
       sol.dataConclusao,
       sol.statusExecucao,
       s.nomeServico,
       s.horas,
       s.imagem,
       o.nomeOng,
       o.foto_perfil       AS fotoOng
     FROM Mutuo_SolicitacaoONG sol
     JOIN Mutuo_ServicoOng s ON sol.codServico = s.id
     JOIN Mutuo_ONG o        ON s.cnpj = o.cnpj
     WHERE sol.codUsuario = ?
       AND sol.statusExecucao = 'Realizada'
     ORDER BY COALESCE(sol.dataConclusao, sol.dataSolicitacao) DESC`,
    [cpf]
  );

  const [[usuario]] = await pool.query(
    `SELECT pontos FROM Mutuo_Usuario WHERE cpf = ?`,
    [cpf]
  );

  const ongsAjudadas = new Set(servicos.map(s => s.nomeOng)).size;

  return {
    resumo: {
      servicosConcluidos: servicos.length,
      ongsAjudadas,
      pontos: usuario?.pontos ?? 0
    },
    servicos
  };
}

const { randomUUID } = require('crypto');

async function buscarDadosCertificado(cpf, codSolicitacao) {
  const [[dados]] = await pool.query(
    `SELECT sol.codSolicitacao, sol.dataConclusao, sol.dataSolicitacao, sol.codigoVerificacao,
            s.nomeServico, s.horas, o.nomeOng, u.nome AS nomeUsuario
     FROM Mutuo_SolicitacaoONG sol
     JOIN Mutuo_ServicoOng s ON sol.codServico = s.id
     JOIN Mutuo_ONG o        ON s.cnpj = o.cnpj
     JOIN Mutuo_Usuario u    ON sol.codUsuario = u.cpf
     WHERE sol.codUsuario = ? AND sol.codSolicitacao = ? AND sol.statusExecucao = 'Realizada'`,
    [cpf, codSolicitacao]
  );

  if (!dados) return null;

  // gera o código só na primeira vez que o certificado é emitido
  if (!dados.codigoVerificacao) {
    const codigo = randomUUID();
    await pool.query('UPDATE Mutuo_SolicitacaoONG SET codigoVerificacao = ? WHERE codSolicitacao = ?', [codigo, codSolicitacao]);
    dados.codigoVerificacao = codigo;
  }

  return dados;
}

async function verificarCertificado(codigo) {
  const [[dados]] = await pool.query(
    `SELECT sol.dataConclusao, s.nomeServico, s.horas, o.nomeOng, u.nome AS nomeUsuario
     FROM Mutuo_SolicitacaoONG sol
     JOIN Mutuo_ServicoOng s ON sol.codServico = s.id
     JOIN Mutuo_ONG o        ON s.cnpj = o.cnpj
     JOIN Mutuo_Usuario u    ON sol.codUsuario = u.cpf
     WHERE sol.codigoVerificacao = ?`,
    [codigo]
  );
  return dados || null;
}

async function buscarCertificadosPorOng(cnpj) {
  const [servicos] = await pool.query(
    `SELECT 
       sol.codSolicitacao,
       sol.pontos          AS pontosSolicitacao,
       sol.dataSolicitacao,
       sol.dataConclusao,
       sol.codigoVerificacao,
       s.nomeServico,
       s.foco,
       u.nome               AS nomeUsuario
     FROM Mutuo_SolicitacaoONG sol
     JOIN Mutuo_ServicoOng s ON sol.codServico = s.id
     JOIN Mutuo_Usuario u    ON sol.codUsuario = u.cpf
     WHERE s.cnpj = ?
       AND sol.statusExecucao = 'Realizada'
     ORDER BY COALESCE(sol.dataConclusao, sol.dataSolicitacao) DESC`,
    [cnpj]
  );

  const totalVoluntarios = new Set(servicos.map(s => s.nomeUsuario)).size;
  const certificadosEmitidos = servicos.filter(s => s.codigoVerificacao != null).length;
  const pontosDistribuidos = servicos.reduce((acc, s) => acc + Number(s.pontosSolicitacao || 0), 0);

  return {
    resumo: {
      totalVoluntarios,
      certificadosEmitidos,
      servicosConcluidos: servicos.length,
      pontosDistribuidos
    },
    servicos
  };
}

// Lista serviços em destaque — apenas de usuários premium, excluindo o próprio usuário
async function getServicosDestaque(cpfExcluir) {
  const sql = `
    SELECT 
      s.cod,
      s.nome,
      s.descricao,
      s.foco,
      s.qtdHoras,
      s.imagem,
      s.pontos,
      s.idUsuario,
      u.nome AS nomeUsuario,
      u.cidade,
      u.estado,
      u.foto_perfil AS fotoUsuario
    FROM Mutuo_Servico AS s
    JOIN Mutuo_Usuario AS u ON s.idUsuario = u.cpf
    WHERE s.ativo = 1 AND u.ativo = 1 AND u.premium = 1
      ${cpfExcluir ? 'AND s.idUsuario != ?' : ''}
    ORDER BY s.cod DESC
  `;
  try {
    const params = cpfExcluir ? [cpfExcluir] : [];
    const [rows] = await pool.query(sql, params);
    return rows.map(servico => ({
      ...servico,
      imagem: servico.imagem ? `/uploads/servicos/${servico.imagem}` : null,
      fotoUsuario: servico.fotoUsuario ? `/uploads/fotos/${servico.fotoUsuario}` : null
    }));
  } catch (err) {
    console.error('Erro ao buscar serviços em destaque:', err.message);
    return { error: err.message };
  }
}

// Lista serviços de usuários premium na mesma cidade, excluindo o próprio usuário
async function getServicosPertoDeVoce(cidade, cpfExcluir) {
  const sql = `
    SELECT 
      s.cod,
      s.nome,
      s.descricao,
      s.foco,
      s.qtdHoras,
      s.imagem,
      s.pontos,
      s.idUsuario,
      u.nome AS nomeUsuario,
      u.cidade,
      u.estado,
      u.foto_perfil AS fotoUsuario
    FROM Mutuo_Servico AS s
    JOIN Mutuo_Usuario AS u ON s.idUsuario = u.cpf
    WHERE s.ativo = 1 AND u.ativo = 1 AND u.premium = 1 AND u.cidade = ?
      ${cpfExcluir ? 'AND s.idUsuario != ?' : ''}
    ORDER BY s.cod DESC
  `;
  try {
    const params = cpfExcluir ? [cidade, cpfExcluir] : [cidade];
    const [rows] = await pool.query(sql, params);
    return rows.map(servico => ({
      ...servico,
      imagem: servico.imagem ? `/uploads/servicos/${servico.imagem}` : null,
      fotoUsuario: servico.fotoUsuario ? `/uploads/fotos/${servico.fotoUsuario}` : null
    }));
  } catch (err) {
    console.error('Erro ao buscar serviços perto de você:', err.message);
    return { error: err.message };
  }
}
// Conta quantos serviços ATIVOS um usuário já tem cadastrados
async function contarServicosAtivosUsuario(cpf) {
  try {
    const [rows] = await pool.query(
      'SELECT COUNT(*) AS total FROM Mutuo_Servico WHERE idUsuario = ? AND ativo = 1',
      [cpf]
    );
    return rows[0].total;
  } catch (err) {
    console.error('Erro ao contar serviços do usuário:', err.message);
    throw err;
  }
}

// Verifica se o usuário é premium (usa a coluna Mutuo_Usuario.premium)
async function isUsuarioPremium(cpf) {
  try {
    const [rows] = await pool.query(
      'SELECT premium FROM Mutuo_Usuario WHERE cpf = ?',
      [cpf]
    );
    if (rows.length === 0) return false;
    const valor = rows[0].premium;
    return valor === true || Number(valor) === 1 ||
      (Buffer.isBuffer(valor) && valor[0] === 1);
  } catch (err) {
    console.error('Erro ao verificar premium do usuário:', err.message);
    throw err;
  }
}

// Ativa/desativa o plano premium do usuário
async function atualizarPremiumUsuario(cpf, premium) {
  try {
    const [result] = await pool.query(
      'UPDATE Mutuo_Usuario SET premium = ? WHERE cpf = ?',
      [premium, cpf]
    );

    return {
      success: result.affectedRows > 0
    };
  } catch (err) {
    console.error('Erro ao atualizar premium do usuário:', err.message);
    return { error: err.message };
  }
}
async function atualizarPremiumOng(cnpj, premium) {
  try {
    const [result] = await pool.query(
      'UPDATE Mutuo_ONG SET premium = ? WHERE cnpj = ?',
      [premium, cnpj]
    );

    return {
      success: result.affectedRows > 0,
      premium
    };
  } catch (err) {
    console.error(
      'Erro ao atualizar Premium da ONG:',
      err.message
    );

    return {
      error: err.message
    };
  }
}

// Conta quantos serviços ATIVOS uma ONG já tem cadastrados
async function contarServicosAtivosOng(cnpj) {
  try {
    const [rows] = await pool.query(
      'SELECT COUNT(*) AS total FROM Mutuo_ServicoOng WHERE cnpj = ? AND ativo = 1',
      [cnpj]
    );
    return rows[0].total;
  } catch (err) {
    console.error('Erro ao contar serviços da ONG:', err.message);
    throw err;
  }
}

// Verifica se a ONG é premium 
async function isOngPremium(cnpj) {
  try {
    const [rows] = await pool.query(
      'SELECT premium FROM Mutuo_ONG WHERE cnpj = ?',
      [cnpj]
    );

    if (rows.length === 0) return false;

    const valor = rows[0].premium;

    return valor === true ||
      Number(valor) === 1 ||
      (Buffer.isBuffer(valor) && valor[0] === 1);
  } catch (err) {
    console.error('Erro ao verificar premium da ONG:', err.message);
    throw err;
  }
}

// confirmação de serviços e avaliação


// Solicitações aceitas aguardando confirmação (aba "Confirmar Serviços" do perfil)
async function getSolicitacoesParaConfirmar(cpfUsuario) {
  const sql = `
    SELECT 
      SOL.codSolicitacao,
      SOL.pontos,
      SOL.dataSolicitacao,
      SERV.nome AS nomeServico,
      UPRES.nome AS nomePrestador
    FROM Mutuo_Solicitacao AS SOL
    JOIN Mutuo_Servico AS SERV ON SOL.codServico = SERV.cod
    JOIN Mutuo_Usuario AS UPRES ON SERV.idUsuario = UPRES.cpf
    WHERE SOL.codUsuario = ?
      AND SOL.statusSolicitacao = 'Aceita'
      AND SOL.statusExecucao != 'Realizada'
    ORDER BY SOL.dataSolicitacao DESC
  `;
  try {
    const [rows] = await pool.query(sql, [cpfUsuario]);
    return rows;
  } catch (err) {
    console.error('Erro ao buscar solicitações para confirmar:', err.message);
    return { error: err.message };
  }
}

// movimentação mensal de pontos
async function getMovimentacaoMensal(cpf) {
  const sql = `
    SELECT 
      COALESCE((
        SELECT SUM(sol.pontos)
        FROM Mutuo_Solicitacao sol
        JOIN Mutuo_Servico s ON sol.codServico = s.cod
        WHERE s.idUsuario = ?
          AND sol.statusExecucao = 'Realizada'
          AND MONTH(sol.dataConclusao) = MONTH(CURDATE())
          AND YEAR(sol.dataConclusao) = YEAR(CURDATE())
      ), 0)
      +
      COALESCE((
        SELECT SUM(solOng.pontos)
        FROM Mutuo_SolicitacaoONG solOng
        WHERE solOng.codUsuario = ?
          AND solOng.statusExecucao = 'Realizada'
          AND MONTH(solOng.dataConclusao) = MONTH(CURDATE())
          AND YEAR(solOng.dataConclusao) = YEAR(CURDATE())
      ), 0) AS recebidos,
      COALESCE((
        SELECT SUM(sol.pontos)
        FROM Mutuo_Solicitacao sol
        WHERE sol.codUsuario = ?
          AND sol.statusExecucao = 'Realizada'
          AND MONTH(sol.dataConclusao) = MONTH(CURDATE())
          AND YEAR(sol.dataConclusao) = YEAR(CURDATE())
      ), 0) AS gastos
  `;
  try {
    const [[resultado]] = await pool.query(sql, [cpf, cpf, cpf]);
    return resultado;
  } catch (err) {
    console.error('Erro ao buscar movimentação mensal:', err.message);
    return { error: err.message };
  }
}

// Confirmar realização → transfere pontos (transação)
async function confirmarSolicitacao(cod) {
  const conexao = await pool.getConnection();
  try {
    await conexao.beginTransaction();

    const [[solicitacao]] = await conexao.query(
      `SELECT sol.codUsuario, sol.codServico, sol.statusExecucao, 
              s.pontos AS pontosServico, s.idUsuario AS prestadorCpf
       FROM Mutuo_Solicitacao sol
       JOIN Mutuo_Servico s ON sol.codServico = s.cod
       WHERE sol.codSolicitacao = ?
       FOR UPDATE`,
      [cod]
    );

    if (!solicitacao) throw new Error('Solicitação não encontrada.');
    if (solicitacao.statusExecucao === 'Realizada') throw new Error('Este serviço já foi confirmado.');

    const { pontosServico, codUsuario, codServico, prestadorCpf } = solicitacao;

    const [resultado1] = await conexao.query(`UPDATE Mutuo_Usuario SET pontos = pontos - ? WHERE cpf = ?`, [pontosServico, codUsuario]);
    const [resultado2] = await conexao.query(`UPDATE Mutuo_Usuario SET pontos = pontos + ? WHERE cpf = ?`, [pontosServico, prestadorCpf]);

    if (resultado1.affectedRows === 0 || resultado2.affectedRows === 0) {
      throw new Error('Falha ao atualizar pontos dos usuários.');
    }

    await conexao.query(
      `UPDATE Mutuo_Solicitacao SET statusExecucao = 'Realizada', dataConclusao = NOW(), pontos = ? WHERE codSolicitacao = ?`,
      [pontosServico, cod]
    );

    await conexao.commit();
    return { sucesso: true, codServico };
  } catch (err) {
    await conexao.rollback();
    console.error('Erro ao confirmar solicitação:', err.message);
    return { error: err.message };
  } finally {
    conexao.release();
  }
}

// Avaliar o serviço (média ponderada)
async function avaliarSolicitacao(cod, notaNova) {
  const conexao = await pool.getConnection();
  try {
    await conexao.beginTransaction();

    const [[solicitacao]] = await conexao.query(
      `SELECT codServico, avaliado FROM Mutuo_Solicitacao WHERE codSolicitacao = ? FOR UPDATE`,
      [cod]
    );
    if (!solicitacao) throw new Error('Solicitação não encontrada.');
    if (solicitacao.avaliado) throw new Error('Este serviço já foi avaliado.');

    const [[servico]] = await conexao.query(
      `SELECT nota, avaliacoes FROM Mutuo_Servico WHERE cod = ? FOR UPDATE`,
      [solicitacao.codServico]
    );

    const novaQtd = servico.avaliacoes + 1;
    const novaMedia = servico.avaliacoes === 0
      ? notaNova
      : ((servico.nota * servico.avaliacoes) + notaNova) / novaQtd;

    await conexao.query(`UPDATE Mutuo_Servico SET nota = ?, avaliacoes = ? WHERE cod = ?`, [novaMedia.toFixed(1), novaQtd, solicitacao.codServico]);
    await conexao.query(`UPDATE Mutuo_Solicitacao SET avaliado = 1, nota = ? WHERE codSolicitacao = ?`, [notaNova, cod]); // ← salva a nota individual

    await conexao.commit();
    return { sucesso: true };
  } catch (err) {
    await conexao.rollback();
    console.error('Erro ao avaliar solicitação:', err.message);
    return { error: err.message };
  } finally {
    conexao.release();
  }
}

// Conta usuários distintos que concluíram serviços pertencentes a uma ONG
async function contarVoluntariosOng(cnpj) {
  try {
    const [rows] = await pool.query(
      `SELECT COUNT(DISTINCT SOL.codUsuario) AS totalVoluntarios
       FROM Mutuo_SolicitacaoONG AS SOL
       JOIN Mutuo_ServicoOng AS SERV
         ON SOL.codServico = SERV.id
       WHERE SERV.cnpj = ?
         AND SOL.statusExecucao = 'Realizada'`,
      [cnpj]
    );

    return Number(rows[0]?.totalVoluntarios || 0);
  } catch (err) {
    console.error(
      'Erro ao contar voluntários da ONG:',
      err.message
    );

    throw err;
  }
}

//marcar mensagem das notificações como lida
async function marcarSolicitacaoLida(cod) {
  try {
    await pool.query(`UPDATE Mutuo_Solicitacao SET lida = 1 WHERE codSolicitacao = ?`, [cod]);
    return { sucesso: true };
  } catch (err) {
    console.error('Erro ao marcar como lida:', err.message);
    return { error: err.message };
  }
}

// notificações
async function contarNaoLidas(cpf) {
  try {
    const [[resultado]] = await pool.query(
      `SELECT COUNT(*) AS total 
       FROM Mutuo_Solicitacao SOL
       JOIN Mutuo_Servico SERV ON SOL.codServico = SERV.cod
       WHERE SERV.idUsuario = ? AND SOL.lida = 0`,
      [cpf]
    );
    return resultado.total;
  } catch (err) {
    console.error('Erro ao contar não lidas:', err.message);
    return { error: err.message };
  }
}

async function getServicosRecebidosOng(cnpj) {
  const sql = `
    SELECT
      SOL.codSolicitacao,
      SOL.pontos,
      SOL.dataSolicitacao,
      SOL.dataConclusao,
      SERV.nomeServico,
      U.nome AS nomeVoluntario
    FROM Mutuo_SolicitacaoONG SOL
    JOIN Mutuo_ServicoOng SERV ON SOL.codServico = SERV.id
    JOIN Mutuo_Usuario U ON SOL.codUsuario = U.cpf
    WHERE SERV.cnpj = ?
      AND SOL.statusExecucao = 'Realizada'
    ORDER BY SOL.dataConclusao DESC
  `;
  try {
    const [rows] = await pool.query(sql, [cnpj]);
    return rows;
  } catch (err) {
    console.error('Erro ao buscar serviços recebidos da ONG:', err.message);
    return { error: err.message };
  }
}

// ── Chat ──

// Normaliza a ordem dos dois participantes (por tipo+id concatenados) para
// que A→B e B→A sempre caiam na mesma linha de Mutuo_Conversa.
function normalizarParticipantes(tipo1, id1, tipo2, id2) {
  const chave1 = `${tipo1}:${id1}`;
  const chave2 = `${tipo2}:${id2}`;
  if (chave1 <= chave2) return { tipo1, id1, tipo2, id2 };
  return { tipo1: tipo2, id1: id2, tipo2: tipo1, id2: id1 };
}

async function buscarOuCriarConversa(tipo1, id1, tipo2, id2) {
  try {
    const p = normalizarParticipantes(tipo1, id1, tipo2, id2);

    const [existentes] = await pool.query(
      `SELECT * FROM Mutuo_Conversa
       WHERE tipo_participante_1 = ? AND id_participante_1 = ?
         AND tipo_participante_2 = ? AND id_participante_2 = ?`,
      [p.tipo1, p.id1, p.tipo2, p.id2]
    );
    if (existentes.length > 0) return existentes[0];

    const [result] = await pool.query(
      `INSERT INTO Mutuo_Conversa (tipo_participante_1, id_participante_1, tipo_participante_2, id_participante_2)
       VALUES (?, ?, ?, ?)`,
      [p.tipo1, p.id1, p.tipo2, p.id2]
    );

    const [[nova]] = await pool.query('SELECT * FROM Mutuo_Conversa WHERE id = ?', [result.insertId]);
    return nova;
  } catch (err) {
    console.error('Erro ao buscar ou criar conversa:', err.message);
    return { error: err.message };
  }
}

// Lista as conversas de uma conta, trazendo nome/foto do outro participante,
// prévia da última mensagem e contagem de não lidas.
async function getConversasDaConta(tipo, id) {
  try {
    const [conversas] = await pool.query(
      `SELECT c.*,
              (SELECT m.conteudo FROM Mutuo_Mensagem m
                 WHERE m.conversa_id = c.id
                   AND m.enviada_em > COALESCE(
                     CASE WHEN c.tipo_participante_1 = ? AND c.id_participante_1 = ?
                          THEN c.limpo_em_participante_1
                          ELSE c.limpo_em_participante_2 END,
                     '1970-01-01'
                   )
                 ORDER BY m.enviada_em DESC LIMIT 1) AS ultimaMensagem,
              (SELECT COUNT(*) FROM Mutuo_Mensagem m WHERE m.conversa_id = c.id AND m.lida = 0 AND NOT (m.tipo_remetente = ? AND m.id_remetente = ?)) AS naoLidas
       FROM Mutuo_Conversa c
       WHERE (c.tipo_participante_1 = ? AND c.id_participante_1 = ?)
          OR (c.tipo_participante_2 = ? AND c.id_participante_2 = ?)
       ORDER BY c.ultima_mensagem_em DESC`,
      [tipo, id, tipo, id, tipo, id, tipo, id]
    );

    return await Promise.all(conversas.map(async (c) => {
      const souParticipante1 = c.tipo_participante_1 === tipo && c.id_participante_1 === id;
      const tipoOutraConta = souParticipante1 ? c.tipo_participante_2 : c.tipo_participante_1;
      const idOutraConta = souParticipante1 ? c.id_participante_2 : c.id_participante_1;

      let nomeOutraConta = null;
      let fotoOutraConta = null;

      if (tipoOutraConta === 'usuario') {
        const [[u]] = await pool.query('SELECT nome, foto_perfil FROM Mutuo_Usuario WHERE cpf = ?', [idOutraConta]);
        if (u) {
          nomeOutraConta = u.nome;
          fotoOutraConta = u.foto_perfil ? `/uploads/fotos/${u.foto_perfil}` : null;
        }
      } else {
        const [[o]] = await pool.query('SELECT nomeOng, foto_perfil FROM Mutuo_ONG WHERE cnpj = ?', [idOutraConta]);
        if (o) {
          nomeOutraConta = o.nomeOng;
          fotoOutraConta = o.foto_perfil ? `/uploads/fotos/${o.foto_perfil}` : null;
        }
      }

      return {
        id: c.id,
        tipoOutraConta,
        idOutraConta,
        nomeOutraConta,
        fotoOutraConta,
        ultimaMensagem: c.ultimaMensagem,
        ultimaMensagemEm: c.ultima_mensagem_em,
        naoLidas: Number(c.naoLidas) || 0
      };
    }));
  } catch (err) {
    console.error('Erro ao buscar conversas da conta:', err.message);
    return { error: err.message };
  }
}

async function getConversaPorId(conversaId) {
  try {
    const [[conversa]] = await pool.query('SELECT * FROM Mutuo_Conversa WHERE id = ?', [conversaId]);
    return conversa || null;
  } catch (err) {
    console.error('Erro ao buscar conversa por id:', err.message);
    return { error: err.message };
  }
}

async function getMensagens(conversaId, desde, tipoSolicitante, idSolicitante) {
  try {
    let limpoEm = null;
    if (tipoSolicitante && idSolicitante) {
      const conversa = await getConversaPorId(conversaId);
      if (conversa && !conversa.error) {
        const souParticipante1 =
          conversa.tipo_participante_1 === tipoSolicitante &&
          conversa.id_participante_1 === idSolicitante;
        limpoEm = souParticipante1
          ? conversa.limpo_em_participante_1
          : conversa.limpo_em_participante_2;
      }
    }

    let sql = 'SELECT * FROM Mutuo_Mensagem WHERE conversa_id = ?';
    const params = [conversaId];
    if (desde) {
      sql += ' AND enviada_em > ?';
      params.push(new Date(desde));
    }
    if (limpoEm) {
      sql += ' AND enviada_em > ?';
      params.push(limpoEm);
    }
    sql += ' ORDER BY enviada_em ASC';
    const [rows] = await pool.query(sql, params);
    return rows;
  } catch (err) {
    console.error('Erro ao buscar mensagens:', err.message);
    return { error: err.message };
  }
}

async function criarMensagem(conversaId, tipoRemetente, idRemetente, conteudo) {
  try {
    const [result] = await pool.query(
      'INSERT INTO Mutuo_Mensagem (conversa_id, tipo_remetente, id_remetente, conteudo) VALUES (?, ?, ?, ?)',
      [conversaId, tipoRemetente, idRemetente, conteudo]
    );
    await pool.query('UPDATE Mutuo_Conversa SET ultima_mensagem_em = NOW() WHERE id = ?', [conversaId]);

    const [[mensagem]] = await pool.query('SELECT * FROM Mutuo_Mensagem WHERE id = ?', [result.insertId]);
    return mensagem;
  } catch (err) {
    console.error('Erro ao criar mensagem:', err.message);
    return { error: err.message };
  }
}

async function marcarConversaComoLida(conversaId, tipoLeitor, idLeitor) {
  try {
    await pool.query(
      `UPDATE Mutuo_Mensagem SET lida = 1
       WHERE conversa_id = ? AND NOT (tipo_remetente = ? AND id_remetente = ?)`,
      [conversaId, tipoLeitor, idLeitor]
    );
    return { sucesso: true };
  } catch (err) {
    console.error('Erro ao marcar conversa como lida:', err.message);
    return { error: err.message };
  }
}

// PERFIL ONG -> PARTE DO USUÁRIO

async function buscarServicosAtivosOng(cnpj) {
  try {
    const [servicos] = await pool.query(
      `SELECT id, nomeServico, horas, descricao, foco, imagem, pontos
       FROM Mutuo_ServicoOng WHERE cnpj = ? AND ativo = 1`,
      [cnpj]
    );
    return servicos;
  } catch (err) {
    console.error('Erro ao buscar serviços da ONG:', err.message);
    return { error: err.message };
  }
}

// Marca "limpo_em" no slot do participante correspondente (1 ou 2). A partir
// desse timestamp, mensagens anteriores somem só pra essa conta — a outra
// continua vendo o histórico completo.
async function limparConversaParaConta(conversaId, tipo, id) {
  try {
    const conversa = await getConversaPorId(conversaId);
    if (!conversa || conversa.error) return { error: 'Conversa não encontrada.' };

    const souParticipante1 =
      conversa.tipo_participante_1 === tipo && conversa.id_participante_1 === id;
    const souParticipante2 =
      conversa.tipo_participante_2 === tipo && conversa.id_participante_2 === id;

    if (!souParticipante1 && !souParticipante2) {
      return { error: 'Essa conta não participa dessa conversa.' };
    }

    const coluna = souParticipante1 ? 'limpo_em_participante_1' : 'limpo_em_participante_2';
    await pool.query(
      `UPDATE Mutuo_Conversa SET ${coluna} = NOW() WHERE id = ?`,
      [conversaId]
    );
    return { sucesso: true };
  } catch (err) {
    console.error('Erro ao limpar conversa:', err.message);
    return { error: err.message };
  }
}

// NOTIFICAÇÕES E PONTOS -> LADO DA ONG

// Notificações do lado do usuário (status da oferta que ele fez pra uma ONG)
async function getSolicitacoesOngUsuario(cpf) {
  const sql = `
    SELECT
      SOL.codSolicitacao,
      SOL.statusSolicitacao,
      SOL.statusExecucao,
      SOL.dataSolicitacao,
      SOL.pontos,
      SERV.nomeServico,
      ONG.nomeOng,
      ONG.cnpj AS cnpjOng,
      ONG.foto_perfil AS fotoOng
    FROM Mutuo_SolicitacaoONG AS SOL
    JOIN Mutuo_ServicoOng AS SERV ON SOL.codServico = SERV.id
    JOIN Mutuo_ONG AS ONG ON SERV.cnpj = ONG.cnpj
    WHERE SOL.codUsuario = ?
    ORDER BY SOL.dataSolicitacao DESC
  `;
  try {
    const [rows] = await pool.query(sql, [cpf]);
    return rows.map(r => ({
      ...r,
      fotoOng: r.fotoOng ? `/uploads/fotos/${r.fotoOng}` : null
    }));
  } catch (err) {
    console.error('Erro ao buscar solicitações de ONG do usuário:', err.message);
    return { error: err.message };
  }
}

// Aba "Confirmar Serviços" do perfil da ONG
async function getSolicitacoesOngParaConfirmar(cnpj) {
  const sql = `
    SELECT
      SOL.codSolicitacao,
      SOL.pontos,
      SOL.dataSolicitacao,
      SERV.nomeServico,
      U.nome AS nomeVoluntario
    FROM Mutuo_SolicitacaoONG SOL
    JOIN Mutuo_ServicoOng SERV ON SOL.codServico = SERV.id
    JOIN Mutuo_Usuario U ON SOL.codUsuario = U.cpf
    WHERE SERV.cnpj = ?
      AND SOL.statusSolicitacao = 'Aceita'
      AND SOL.statusExecucao != 'Realizada'
    ORDER BY SOL.dataSolicitacao DESC
  `;
  try {
    const [rows] = await pool.query(sql, [cnpj]);
    return rows;
  } catch (err) {
    console.error('Erro ao buscar solicitações da ONG para confirmar:', err.message);
    return { error: err.message };
  }
}

// Confirmar realização → transfere pontos da ONG para o voluntário (transação)
async function confirmarSolicitacaoOng(cod) {
  const conexao = await pool.getConnection();
  try {
    await conexao.beginTransaction();

    const [[solicitacao]] = await conexao.query(
      `SELECT SOL.codUsuario, SOL.statusExecucao, SERV.pontos AS pontosServico, SERV.cnpj AS cnpjOng
       FROM Mutuo_SolicitacaoONG SOL
       JOIN Mutuo_ServicoOng SERV ON SOL.codServico = SERV.id
       WHERE SOL.codSolicitacao = ?
       FOR UPDATE`,
      [cod]
    );

    if (!solicitacao) throw new Error('Solicitação não encontrada.');
    if (solicitacao.statusExecucao === 'Realizada') throw new Error('Este serviço já foi confirmado.');

    const { pontosServico, codUsuario, cnpjOng } = solicitacao;

    const [r1] = await conexao.query(`UPDATE Mutuo_ONG SET pontos = pontos - ? WHERE cnpj = ?`, [pontosServico, cnpjOng]);
    const [r2] = await conexao.query(`UPDATE Mutuo_Usuario SET pontos = pontos + ? WHERE cpf = ?`, [pontosServico, codUsuario]);

    if (r1.affectedRows === 0 || r2.affectedRows === 0) {
      throw new Error('Falha ao atualizar pontos.');
    }

    await conexao.query(
      `UPDATE Mutuo_SolicitacaoONG SET statusExecucao = 'Realizada', dataConclusao = NOW(), pontos = ? WHERE codSolicitacao = ?`,
      [pontosServico, cod]
    );

    await conexao.commit();
    return { sucesso: true };
  } catch (err) {
    await conexao.rollback();
    console.error('Erro ao confirmar solicitação da ONG:', err.message);
    return { error: err.message };
  } finally {
    conexao.release();
  }
}

// Bônus mensal de 500 pontos — aplicado uma vez por mês, no primeiro carregamento do perfil
async function verificarBonusMensalOng(cnpj) {
  try {
    const [[ong]] = await pool.query(`SELECT ultimoBonusMensal, pontos FROM Mutuo_ONG WHERE cnpj = ?`, [cnpj]);
    if (!ong) return { error: 'ONG não encontrada.' };

    const hoje = new Date();
    const mesAtual = hoje.getMonth();
    const anoAtual = hoje.getFullYear();

    let jaRecebeu = false;
    if (ong.ultimoBonusMensal) {
      const ultima = new Date(ong.ultimoBonusMensal);
      jaRecebeu = ultima.getMonth() === mesAtual && ultima.getFullYear() === anoAtual;
    }

    if (!jaRecebeu && ong.pontos <= 1000) {
      await pool.query(
        `UPDATE Mutuo_ONG SET pontos = pontos + 500, ultimoBonusMensal = CURDATE() WHERE cnpj = ?`,
        [cnpj]
      );
      return { aplicado: true };
    }

    // Mesmo não aplicando bônus (por já ter recebido ou por estar acima do teto),
    // marca a data pra não ficar testando o teto repetidamente todo santo dia.
    if (!jaRecebeu && ong.pontos > 1000) {
      await pool.query(`UPDATE Mutuo_ONG SET ultimoBonusMensal = CURDATE() WHERE cnpj = ?`, [cnpj]);
    }

    return { aplicado: false };
  } catch (err) {
    console.error('Erro ao verificar bônus mensal da ONG:', err.message);
    return { error: err.message };
  }
}

// Movimentação mensal de pontos da ONG (gastos com confirmações + bônus recebido)
async function getMovimentacaoMensalOng(cnpj) {
  const sql = `
    SELECT 
      COALESCE((
        SELECT SUM(SOL.pontos)
        FROM Mutuo_SolicitacaoONG SOL
        JOIN Mutuo_ServicoOng SERV ON SOL.codServico = SERV.id
        WHERE SERV.cnpj = ?
          AND SOL.statusExecucao = 'Realizada'
          AND MONTH(SOL.dataConclusao) = MONTH(CURDATE())
          AND YEAR(SOL.dataConclusao) = YEAR(CURDATE())
      ), 0) AS gastos,
      (
        SELECT CASE 
          WHEN ultimoBonusMensal IS NOT NULL 
            AND MONTH(ultimoBonusMensal) = MONTH(CURDATE()) 
            AND YEAR(ultimoBonusMensal) = YEAR(CURDATE())
          THEN 500 ELSE 0 END
        FROM Mutuo_ONG WHERE cnpj = ?
      ) AS recebidos
  `;
  try {
    const [[resultado]] = await pool.query(sql, [cnpj, cnpj]);
    return resultado;
  } catch (err) {
    console.error('Erro ao buscar movimentação mensal da ONG:', err.message);
    return { error: err.message };
  }
}

// Upsert do token FCM de um dispositivo: se o token já existe, atualiza qual
// conta ele pertence agora e o timestamp (troca de login no mesmo aparelho).
async function salvarTokenDispositivo(tipo, identificador, token) {
  try {
    await pool.query(
      `INSERT INTO Mutuo_DispositivoToken (tipo, identificador, token_fcm)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE tipo = VALUES(tipo), identificador = VALUES(identificador), atualizado_em = NOW()`,
      [tipo, identificador, token]
    );
    return { sucesso: true };
  } catch (err) {
    console.error('Erro ao salvar token de dispositivo:', err.message);
    return { error: err.message };
  }
}

async function getTokensDaConta(tipo, identificador) {
  try {
    const [rows] = await pool.query(
      'SELECT token_fcm FROM Mutuo_DispositivoToken WHERE tipo = ? AND identificador = ?',
      [tipo, identificador]
    );
    return rows.map((r) => r.token_fcm);
  } catch (err) {
    console.error('Erro ao buscar tokens da conta:', err.message);
    return { error: err.message };
  }
}

// Remove tokens que o Firebase reportou como inválidos/desregistrados após um envio.
async function removerTokensInvalidos(tokens) {
  if (!tokens.length) return;
  try {
    await pool.query('DELETE FROM Mutuo_DispositivoToken WHERE token_fcm IN (?)', [tokens]);
  } catch (err) {
    console.error('Erro ao remover tokens inválidos:', err.message);
  }
}

module.exports = {
  getUsuarios,
  getUsuarioPorCpf,
  atualizarDadosUsuario,
  validarLogin,
  validarLoginUsuario,
  validarLoginOng,
  countUsuarios,
  countONGs,
  countServicos,
  countHoras,
  countUsuariosInativos,
  countPontos,
  countONGsInativas,
  countPremium,
  countServicosCadastrados,
  countSolicitacoesAceitas,
  countSolicitacoesPendentes,
  countSolicitacoesRecusadas,
  countPontosOng,
  alterUsuario,
  getONGs,
  alterONG,
  mediaNotas,
  getFotoPerfil,
  atualizarFotoPerfil,
  getServicos,
  alterServico,
  getSolicitacoes,
  alterSolicitacao,
  cadastrarUsuario,
  cadastrarOng,
  cadastrarServico,
  cadastrarServicoOng,
  getServicosUsuario,
  atualizarStatusServico,
  getServicoPorId,
  atualizarServico,
  getServicosOng,
  getPremium,
  countPremiumTotal,
  countAtrasadas,
  countReceita,
  alterarLoginAdm,
  alterarSenhaAdm,
  cadastrarAdm,
  getOngPorCnpj,
  getFotoPerfilOng,
  atualizarFotoPerfilOng,
  atualizarDadosOng,
  getServicoOngPorId,
  atualizarServicoOng,
  alterarStatusServicoOng,
  getServicosOngTodos,
  getServicosUsuarioTodos,
  cadastrarSolicitacao,
  getSolicitacoesPrestador,
  getSolicitacoesUsuario,
  getEstatisticasUsuario,
  cadastrarSolicitacaoOng,
  getSolicitacoesOng,
  contarVoluntariosOng,
  alterSolicitacaoOng,
  contarNaoLidasOng,
  marcarSolicitacaoOngLida,
  getSolicitacaoBasica,
  getSolicitacaoOngBasica,
  buscarCertificadosPorUsuario,
  buscarDadosCertificado,
  verificarCertificado,
  buscarCertificadosPorOng,
  getPlanoUsuario,
  getDashboardUsuario,
  getServicosDestaque,
  getServicosPertoDeVoce,
  contarServicosAtivosUsuario,
  isUsuarioPremium,
  atualizarPremiumUsuario,
  atualizarPremiumOng,
  contarServicosAtivosOng,
  isOngPremium,
  getSolicitacoesParaConfirmar,
  confirmarSolicitacao,
  avaliarSolicitacao,
  contarVoluntariosOng,
  isOngPremium,
  marcarSolicitacaoLida,
  contarNaoLidas,
  buscarOuCriarConversa,
  getConversasDaConta,
  getConversaPorId,
  getMensagens,
  criarMensagem,
  marcarConversaComoLida,
  limparConversaParaConta,
  salvarTokenDispositivo,
  getTokensDaConta,
  removerTokensInvalidos,
  getMovimentacaoMensal,
  buscarServicosAtivosOng,
  getSolicitacoesOngUsuario,
  getSolicitacoesOngParaConfirmar,
  confirmarSolicitacaoOng,
  verificarBonusMensalOng,
  getMovimentacaoMensalOng,
  getServicosRecebidosOng
};
