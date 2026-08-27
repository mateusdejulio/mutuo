// Migration: cria a tabela de tokens FCM (Mutuo_DispositivoToken).
// Idempotente — pode ser rodada mais de uma vez sem erro.
// Uso: node migrations/002_push_tokens.js

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
    await pool.query(`
      CREATE TABLE IF NOT EXISTS Mutuo_DispositivoToken (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tipo ENUM('usuario','ong') NOT NULL,
        identificador VARCHAR(20) NOT NULL,
        token_fcm VARCHAR(255) NOT NULL UNIQUE,
        atualizado_em DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('Tabela Mutuo_DispositivoToken OK.');

    console.log('Migration 002_push_tokens concluída com sucesso.');
  } catch (err) {
    console.error('Erro ao rodar migration 002_push_tokens:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

migrar();
