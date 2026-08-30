// Migration: normaliza o campo "foco" (trim + minúsculo) nas tabelas que
// o possuem, pra eliminar duplicatas nos filtros causadas por diferenças
// de maiúscula/minúscula (ex: "Saúde" vs "saúde").
// Idempotente — pode ser rodada mais de uma vez sem erro.
// Uso: node migrations/003_normalizar_foco.js

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });
const mysql = require('mysql2/promise');

const TABELAS = ['Mutuo_ONG', 'Mutuo_Servico', 'Mutuo_ServicoOng'];

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
    for (const tabela of TABELAS) {
      // Comparar "foco <> LOWER(TRIM(foco))" não funciona como guarda aqui:
      // a collation padrão do MySQL é case-insensitive, então a comparação
      // dá falso mesmo com valores em caixa diferente. Por isso a atualização
      // roda sobre todas as linhas não nulas (é um no-op pras já normalizadas).
      const [result] = await pool.query(
        `UPDATE ${tabela} SET foco = LOWER(TRIM(foco)) WHERE foco IS NOT NULL`
      );
      console.log(`${tabela}: ${result.affectedRows} linha(s) normalizada(s).`);
    }

    console.log('Migration 003_normalizar_foco concluída com sucesso.');
  } catch (err) {
    console.error('Erro ao rodar migration 003_normalizar_foco:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

migrar();
