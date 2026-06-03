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
      'SELECT cpf, nome, email, pontos, horasVoluntarias FROM Mutuo_Usuario WHERE email = ? AND senha = ? AND ativo = 1',
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
      'SELECT cnpj, nomeOng, nomeResponsavel, email, foco, premium FROM Mutuo_ONG WHERE email = ? AND senha = ? AND ativo = 1',
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
    (nomeOng, cnpj, email, nomeResponsavel, telefone, cidade, bairro, endereco, estado, senha, foco, descricao)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
    ong.descricao
  ];

  try {
    const [result] = await pool.query(sql, values);
    return result.insertId;
  } catch (error) {
    console.error('Erro ao cadastrar ong:', error);
    throw error;
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
  alterUsuario, 
  getONGs, 
  alterONG, 
  mediaNotas,
  getServicos, 
  alterServico, 
  getSolicitacoes, 
  alterSolicitacao, 
  cadastrarUsuario,
  cadastrarOng,
  getPremium,
  countPremiumTotal,
  countAtrasadas,
  countReceita,
  alterarLoginAdm,
  alterarSenhaAdm,
  cadastrarAdm
};