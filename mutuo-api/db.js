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
      'SELECT cpf, nome, email, telefone, cidade, estado, pontos, horasVoluntarias, cadastro FROM Mutuo_Usuario WHERE email = ? AND senha = ? AND ativo = 1',
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
      SERV.nome AS nomeServico,
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

// Solicitações que ESTE usuário enviou (ele é quem pediu o serviço)
async function getSolicitacoesUsuario(cpfUsuario) {
  const sql = `
    SELECT 
      SOL.codSolicitacao,
      SOL.statusSolicitacao,
      SOL.statusExecucao,
      SOL.dataSolicitacao,
      SOL.pontos,
      SERV.nome AS nomeServico,
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

// Verifica se o usuário tem plano premium ativo (usado no dashboard)
async function getPlanoUsuario(cpf) {
  try {
    const [rows] = await pool.query(
      'SELECT statusPag FROM Mutuo_UsuarioPremium WHERE cpf = ? ORDER BY id DESC LIMIT 1',
      [cpf]
    );
    if (rows.length === 0) return 'Gratuito';
    return rows[0].statusPag === 1 ? 'Premium' : 'Pendente';
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

// Aceita/recusa uma solicitação de serviço de ONG
async function alterSolicitacaoOng(cod, statusS, statusE, pontos) {
  const sql = 'UPDATE Mutuo_SolicitacaoONG SET statusSolicitacao = ?, statusExecucao = ?, pontos = ? WHERE codSolicitacao = ?';
  try {
    const [result] = await pool.query(sql, [statusS, statusE, pontos, cod]);
    return { success: true, affectedRows: result.affectedRows };
  } catch (err) {
    console.error('Erro ao alterar solicitação da ONG:', err.message);
    return { error: err.message };
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

// Lista serviços em destaque — apenas de usuários premium
async function getServicosDestaque() {
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
    console.error('Erro ao buscar serviços em destaque:', err.message);
    return { error: err.message };
  }
}

// Lista serviços de usuários premium na mesma cidade do usuário logado
async function getServicosPertoDeVoce(cidade) {
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
    ORDER BY s.cod DESC
  `;
  try {
    const [rows] = await pool.query(sql, [cidade]);
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
    return rows[0].premium === 1;
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
      [premium ? 1 : 0, cpf]
    );
    return { success: result.affectedRows > 0 };
  } catch (err) {
    console.error('Erro ao atualizar premium do usuário:', err.message);
    return { error: err.message };
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
  alterSolicitacaoOng,
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
  atualizarPremiumUsuario
};