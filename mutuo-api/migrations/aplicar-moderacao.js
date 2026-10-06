// Uso:
//   node migrations/aplicar-moderacao.js --dry-run   (só mostra o que faria)
//   node migrations/aplicar-moderacao.js             (aplica)
// Idempotente: só adiciona as colunas que ainda não existem.
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mysql = require('mysql2/promise');

// Mesma configuração de conexão do db.js
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: '-03:00'
});

const TABELAS = ['Mutuo_Servico', 'Mutuo_ServicoOng'];
const COLUNAS = [
  ['moderacao_status', "ENUM('APROVADO','REVISAO','BLOQUEADO') NOT NULL DEFAULT 'APROVADO'"],
  ['moderacao_categoria', 'VARCHAR(50) NULL'],
  ['moderacao_motivo', 'TEXT NULL'],
  ['moderacao_confianca', 'DECIMAL(4,3) NULL'],
  ['moderacao_data', 'DATETIME NULL'],
  ['moderacao_revisado_por', 'VARCHAR(100) NULL'],
  ['moderacao_data_revisao', 'DATETIME NULL']
];

(async () => {
  const dryRun = process.argv.includes('--dry-run');
  try {
    const [[{ banco }]] = await pool.query('SELECT DATABASE() AS banco');
    console.log(`Conectado ao banco: ${banco} ${dryRun ? '(DRY-RUN: nada será alterado)' : ''}`);

    for (const tabela of TABELAS) {
      const [[{ total }]] = await pool.query(`SELECT COUNT(*) AS total FROM ${tabela}`);
      console.log(`${tabela}: ${total} registros`);

      const [existentes] = await pool.query(
        'SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?',
        [tabela]
      );
      if (existentes.length === 0) throw new Error(`Tabela ${tabela} não encontrada.`);
      const nomes = new Set(existentes.map(c => c.COLUMN_NAME));

      for (const [coluna, definicao] of COLUNAS) {
        if (nomes.has(coluna)) { console.log(`= ${tabela}.${coluna} já existe`); continue; }
        const sql = `ALTER TABLE ${tabela} ADD COLUMN ${coluna} ${definicao}`;
        if (dryRun) { console.log(`+ (simulado) ${sql}`); continue; }
        await pool.query(sql);
        console.log(`+ ${tabela}.${coluna} criada`);
      }
    }

    // Conferência: todos os registros existentes devem estar APROVADO
    if (!dryRun) {
      for (const tabela of TABELAS) {
        const [linhas] = await pool.query(
          `SELECT moderacao_status AS status, COUNT(*) AS total FROM ${tabela} GROUP BY moderacao_status`
        );
        console.log(tabela, linhas);
      }
    }
    console.log('Concluído.');
  } catch (err) {
    console.error('Falha na migration:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
})();
