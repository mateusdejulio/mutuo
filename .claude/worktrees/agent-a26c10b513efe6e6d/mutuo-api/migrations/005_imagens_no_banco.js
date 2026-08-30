// Migration: adiciona colunas pra guardar as imagens (foto de perfil e foto de
// serviço) direto no banco, em vez de arquivo no disco do servidor.
//
// Motivo: o Render (plano gratuito, sem disco persistente) apaga tudo que foi
// salvo em uploads/ toda vez que o serviço reinicia (deploy ou "acordando" do
// modo inativo) — as imagens enviadas pelos usuários somem, mesmo com o nome
// do arquivo continuando salvo no banco. Guardando os bytes da imagem numa
// coluna do próprio MySQL (que já é persistente), a imagem nunca mais some.
//
// Idempotente — pode ser rodada mais de uma vez sem erro.
// Uso: node migrations/005_imagens_no_banco.js

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
    await garantirColuna(pool, 'Mutuo_Usuario', 'foto_perfil_dados', 'LONGBLOB NULL');
    await garantirColuna(pool, 'Mutuo_Usuario', 'foto_perfil_tipo', 'VARCHAR(100) NULL');

    await garantirColuna(pool, 'Mutuo_ONG', 'foto_perfil_dados', 'LONGBLOB NULL');
    await garantirColuna(pool, 'Mutuo_ONG', 'foto_perfil_tipo', 'VARCHAR(100) NULL');

    await garantirColuna(pool, 'Mutuo_Servico', 'imagem_dados', 'LONGBLOB NULL');
    await garantirColuna(pool, 'Mutuo_Servico', 'imagem_tipo', 'VARCHAR(100) NULL');

    await garantirColuna(pool, 'Mutuo_ServicoOng', 'imagem_dados', 'LONGBLOB NULL');
    await garantirColuna(pool, 'Mutuo_ServicoOng', 'imagem_tipo', 'VARCHAR(100) NULL');

    console.log('Migration 005_imagens_no_banco concluída com sucesso.');
  } catch (err) {
    console.error('Erro ao rodar migration 005_imagens_no_banco:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

migrar();
