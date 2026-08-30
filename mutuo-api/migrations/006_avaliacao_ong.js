// Migration: adiciona colunas de avaliação (nota por estrelas) do lado ONG,
// espelhando o que já existe pro usuário comum:
// - Mutuo_SolicitacaoONG.avaliado / .nota — nota individual dada pela ONG
//   ao voluntário quando confirma a realização de uma atividade.
// - Mutuo_ServicoOng.nota / .avaliacoes — média e contagem de avaliações
//   exibidas no card da atividade.
//
// Sem essas colunas o fluxo de "avaliar depois de confirmar" (igual ao
// usuário comum) não tem onde gravar a nota.
//
// Idempotente — pode ser rodada mais de uma vez sem erro.
// Uso: node migrations/006_avaliacao_ong.js

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });
const mysql = require('mysql2/promise');

async function garantirColuna(pool, tabela, coluna, definicao) {
  const [existentes] = await pool.query(`SHOW COLUMNS FROM ${tabela} LIKE ?`, [coluna]);
  if (existentes.length === 0) {
    await pool.query(`ALTER TABLE ${tabela} ADD COLUMN ${coluna} ${definicao}`);
    console.log(`Coluna ${tabela}.${coluna} criada.`);
  } else {
    console.log(`Coluna ${tabela}.${coluna} já existia.`);
  }
}

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
    await garantirColuna(pool, 'Mutuo_SolicitacaoONG', 'avaliado', 'TINYINT(1) NOT NULL DEFAULT 0');
    await garantirColuna(pool, 'Mutuo_SolicitacaoONG', 'nota', 'TINYINT NULL');

    await garantirColuna(pool, 'Mutuo_ServicoOng', 'nota', 'DECIMAL(2,1) NULL');
    await garantirColuna(pool, 'Mutuo_ServicoOng', 'avaliacoes', 'INT NOT NULL DEFAULT 0');

    console.log('Migration 006_avaliacao_ong concluída com sucesso.');
  } catch (err) {
    console.error('Erro ao rodar migration 006_avaliacao_ong:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

migrar();
