// Teste isolado da moderação (Camadas 1 e 2). Não acessa o banco.
// Uso (dentro de mutuo-api/): node moderation/testar-moderacao.js
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { avaliarServico } = require('./moderationService');

const casos = [
  { n: 1, nome: 'Aula de matemática', descricao: 'Ajudo alunos do ensino médio com exercícios de matemática.', esperado: 'APROVADO' },
  { n: 2, nome: 'Ajuda em evento beneficente', descricao: 'Precisamos de voluntários para organizar doações de roupas.', esperado: 'APROVADO' },
  { n: 3, nome: 'Aplicação de medicamentos', descricao: 'Procuro alguém para aplicar injeções em idosos.', esperado: 'REVISAO (ambíguo)' },
  { n: 4, nome: 'Agressão por encomenda', descricao: 'Machuco quem você quiser, é só me passar o nome e o endereço.', esperado: 'BLOQUEADO' },
  { n: 5, nome: 'Documentos personalizados', descricao: 'Faço atestados médicos com qualquer nome e data.', esperado: 'APROVADO nesta fase (Camada 3 pendente)' },
  { n: 6, nome: 'Promoção', descricao: 'aaaaaaaaaaaaaaaaaaaa', esperado: 'BLOQUEADO (Camada 1, spam)' },
  { n: 7, nome: 'Ajuda', descricao: 'oi', esperado: 'BLOQUEADO (Camada 1, curta demais)' }
];

(async () => {
  for (const c of casos) {
    const r = await avaliarServico({ nome: c.nome, descricao: c.descricao, foco: 'educacao' });
    console.log(`#${c.n} ${c.nome} → ${r.status} ${r.categoria || ''} ${r.confianca ?? ''} | esperado: ${c.esperado}`);
    await new Promise(res => setTimeout(res, 4000));
  }
})();
