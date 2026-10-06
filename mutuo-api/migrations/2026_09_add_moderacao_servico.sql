-- Moderação automática de serviços (Camadas 1 e 2).
-- Execução recomendada: node migrations/aplicar-moderacao.js (idempotente).
-- DEFAULT 'APROVADO' mantém todos os serviços existentes visíveis, sem backfill.
-- Aplicar ANTES do deploy do código que usa moderacao_status.

ALTER TABLE Mutuo_Servico
  ADD COLUMN moderacao_status ENUM('APROVADO','REVISAO','BLOQUEADO') NOT NULL DEFAULT 'APROVADO',
  ADD COLUMN moderacao_categoria VARCHAR(50) NULL,
  ADD COLUMN moderacao_motivo TEXT NULL,
  ADD COLUMN moderacao_confianca DECIMAL(4,3) NULL,
  ADD COLUMN moderacao_data DATETIME NULL,
  ADD COLUMN moderacao_revisado_por VARCHAR(100) NULL,
  ADD COLUMN moderacao_data_revisao DATETIME NULL;

ALTER TABLE Mutuo_ServicoOng
  ADD COLUMN moderacao_status ENUM('APROVADO','REVISAO','BLOQUEADO') NOT NULL DEFAULT 'APROVADO',
  ADD COLUMN moderacao_categoria VARCHAR(50) NULL,
  ADD COLUMN moderacao_motivo TEXT NULL,
  ADD COLUMN moderacao_confianca DECIMAL(4,3) NULL,
  ADD COLUMN moderacao_data DATETIME NULL,
  ADD COLUMN moderacao_revisado_por VARCHAR(100) NULL,
  ADD COLUMN moderacao_data_revisao DATETIME NULL;

-- Rollback (só com confirmação):
-- ALTER TABLE Mutuo_Servico
--   DROP COLUMN moderacao_status, DROP COLUMN moderacao_categoria, DROP COLUMN moderacao_motivo,
--   DROP COLUMN moderacao_confianca, DROP COLUMN moderacao_data,
--   DROP COLUMN moderacao_revisado_por, DROP COLUMN moderacao_data_revisao;
-- (idem para Mutuo_ServicoOng)
