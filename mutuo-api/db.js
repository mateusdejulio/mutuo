const mysql = require('mysql2/promise');
const path = require('path');

require('dotenv').config({ path: path.resolve(__dirname, '.env') });

console.log("Tentando conectar ao banco:", process.env.DB_HOST);

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

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
      'SELECT cpf, nome, email, telefone, pontos, horasVoluntarias, cadastro FROM Mutuo_Usuario WHERE email = ? AND senha = ? AND ativo = 1',
      [email, senha]
    );

    if (rows.length > 0) {
      return { sucesso: true, usuario: rows[0] };
    } else {
      return { sucesso: false, mensagem: 'Email ou senha incorretos, ou conta inativa.' };
    }

  } catch (error) {
    console.error('Erro ao validar usuário:', error);
    return { sucesso: false, mensagem: 'Erro interno ao validar login.' };
  }
}


async function validarLoginOng(email, senha) {
  try {
    const [rows] = await pool.query(
      'SELECT cnpj, nomeOng, nomeResponsavel, email, telefone, cidade, estado, foco, premium, cadastro FROM Mutuo_ONG WHERE email = ? AND senha = ? AND ativo = 1',
      [email, senha]
    );

    if (rows.length > 0) {
      return { sucesso: true, usuario: rows[0] };
    } else {
      return { sucesso: false, mensagem: 'Email ou senha incorretos, ou conta inativa.' };
    }
  } catch (error) {
    console.error('Erro ao validar ONG:', error);
    return { sucesso: false, mensagem: 'Erro interno ao validar login.' };
  }
}



async function getUsuarios() {
  const [rows] = await pool.query('SELECT cpf, nome, email, ativo, pontos, horasVoluntarias, cadastro FROM Mutuo_Usuario');
  return rows;
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
      const [result] = await pool.query(sql, [ativo, responsavel, foco, cnpj]);
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
      const [result] = await pool.query(sql, [ativo, horas, foco, nota, cod]);
      return { success: true, affectedRows: result.affectedRows };
    } catch (err) {
      console.error("Erro no db.js/alterServico:", err.message);
      return { error: err.message };
    } 
}

async function alterSolicitacao(cod, statusS, statusE, pontos) {
  const sql = 'UPDATE Mutuo_Solicitacao SET statusSolicitacao = ?, statusExecucao = ?, pontos = ? WHERE codSolicitacao = ?';

  try {
      const [result] = await pool.query(sql, [statusS, statusE, pontos, cod]);
      return { success: true, affectedRows: result.affectedRows };
    } catch (err) {
      console.error("Erro no db.js/alterServico:", err.message);
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

  const values = [
    usuario.cpf,
    usuario.nome,
    usuario.email,
    usuario.senha,
    usuario.telefone,
    usuario.cidade,
    usuario.bairro,
    usuario.cep,
    usuario.nascimento,
    usuario.uf,
    usuario.endereco,
    usuario.cadastro
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
    ong.senha,
    ong.foco,
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
    servico.foco,
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
    servico.foco,
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
  const valores = [servico.nomeServico, servico.descricao, servico.foco, servico.duracao];

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
    const [rows] = await pool.query('SELECT * FROM Mutuo_ONG WHERE cnpj = ?', [cnpj]);
    if (rows.length === 0) return null;
 
    // nunca devolve a senha pro front-end
    const ong = rows[0];
    delete ong.senha;
    return ong;
  } catch (err) {
    console.error('Erro ao buscar ONG por cnpj:', err.message);
    return { error: err.message };
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
  const values = [nomeServico, descricao, foco, horas];
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

module.exports = { 
  getUsuarios, 
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
  alterarStatusServicoOng
};