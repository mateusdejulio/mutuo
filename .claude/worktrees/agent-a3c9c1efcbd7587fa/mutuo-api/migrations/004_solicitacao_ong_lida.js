// Migration: adiciona a coluna "lida" em Mutuo_SolicitacaoONG, espelhando o
// que já existe em Mutuo_Solicitacao — necessária pro badge de notificações
// de solicitações recebidas pela ONG (mesmo padrão do lado usuário).
// Idempotente — pode ser rodada mais de uma vez sem erro.
// Uso: node migrations/004_solicitacao_ong_lida.js

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });
const mysql = require('mysql2/promise');

async function migrar() {
  const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 5,
    queueLimit: 0
  });

  try {
    const [colunas] = await pool.query(`SHOW COLUMNS FROM Mutuo_SolicitacaoONG LIKE 'lida'`);
    if (colunas.length === 0) {
      await pool.query(`ALTER TABLE Mutuo_SolicitacaoONG ADD COLUMN lida TINYINT(1) DEFAULT 0`);
      console.log('Coluna Mutuo_SolicitacaoONG.lida criada.');
    } else {
      console.log('Coluna Mutuo_SolicitacaoONG.lida já existia.');
    }

    console.log('Migration 004_solicitacao_ong_lida concluída com sucesso.');
  } catch (err) {
    console.error('Erro ao rodar migration 004_solicitacao_ong_lida:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

migrar();
