// Migration: cria as tabelas de chat (Mutuo_Conversa, Mutuo_Mensagem).
// Idempotente — pode ser rodada mais de uma vez sem erro.
// Uso: node migrations/001_chat.js

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
      CREATE TABLE IF NOT EXISTS Mutuo_Conversa (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tipo_participante_1 ENUM('usuario','ong') NOT NULL,
        id_participante_1 VARCHAR(20) NOT NULL,
        tipo_participante_2 ENUM('usuario','ong') NOT NULL,
        id_participante_2 VARCHAR(20) NOT NULL,
        criada_em DATETIME DEFAULT CURRENT_TIMESTAMP,
        ultima_mensagem_em DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY par_unico (tipo_participante_1, id_participante_1, tipo_participante_2, id_participante_2)
      )
    `);
    console.log('Tabela Mutuo_Conversa OK.');

    await pool.query(`
      CREATE TABLE IF NOT EXISTS Mutuo_Mensagem (
        id INT AUTO_INCREMENT PRIMARY KEY,
        conversa_id INT NOT NULL,
        tipo_remetente ENUM('usuario','ong') NOT NULL,
        id_remetente VARCHAR(20) NOT NULL,
        conteudo TEXT NOT NULL,
        enviada_em DATETIME DEFAULT CURRENT_TIMESTAMP,
        lida TINYINT(1) DEFAULT 0,
        FOREIGN KEY (conversa_id) REFERENCES Mutuo_Conversa(id)
      )
    `);
    console.log('Tabela Mutuo_Mensagem OK.');

    console.log('Migration 001_chat concluída com sucesso.');
  } catch (err) {
    console.error('Erro ao rodar migration 001_chat:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

migrar();
