// Teste isolado da moderação (Camadas 1, 2 e 3). Não acessa o banco.
// Uso (dentro de mutuo-api/): node moderation/testar-moderacao.js
require('dotenv').config({ path: [require('path').join(__dirname, '..', '.env.local'), require('path').join(__dirname, '..', '.env')] });
const { avaliarServico } = require('./moderationService');

const casos = [
  { n: 1, nome: 'Aula de matemática', descricao: 'Ajudo alunos do ensino médio com exercícios de matemática.', esperado: 'APROVADO' },
  { n: 2, nome: 'Ajuda em evento beneficente', descricao: 'Precisamos de voluntários para organizar doações de roupas.', esperado: 'APROVADO' },
  { n: 3, nome: 'Aplicação de medicamentos', descricao: 'Procuro alguém para aplicar injeções em idosos.', esperado: 'REVISAO (ambíguo)' },
  { n: 4, nome: 'Agressão por encomenda', descricao: 'Machuco quem você quiser, é só me passar o nome e o endereço.', esperado: 'BLOQUEADO' },
  { n: 5, nome: 'Documentos personalizados', descricao: 'Faço atestados médicos com qualquer nome e data.', esperado: 'BLOQUEADO ou REVISAO (Camada 3, FRAUDE)' },
  { n: 6, nome: 'Promoção', descricao: 'aaaaaaaaaaaaaaaaaaaa', esperado: 'BLOQUEADO (Camada 1, spam)' },
  { n: 7, nome: 'Ajuda', descricao: 'oi', esperado: 'BLOQUEADO (Camada 1, curta demais)' },
  { n: 8, nome: 'Remédios sem receita', descricao: 'Consigo remédio tarja preta sem receita, é só combinar comigo.', esperado: 'BLOQUEADO (DROGAS)' },
  { n: 9, nome: 'Filmes e jogos', descricao: 'Passo filmes e jogos pirateados para o seu pendrive.', esperado: 'BLOQUEADO (PIRATARIA)' },
  { n: 10, nome: 'Investimento garantido', descricao: 'Me mande um Pix de 100 reais e eu devolvo 500 em uma semana.', esperado: 'BLOQUEADO (FRAUDE)' },
  { n: 11, nome: 'Conserto de armas', descricao: 'Faço manutenção em armas de fogo sem registro, sigilo total.', esperado: 'BLOQUEADO (ARMAS)' },
  { n: 12, nome: 'Vendo bicicleta', descricao: 'Vendo minha bicicleta aro 29 seminova, aceito propostas.', esperado: 'REVISAO (FORA_DO_ESCOPO)' },
  { n: 13, nome: 'Aulas de violão', descricao: 'Dou aulas de violão para iniciantes aos sábados de manhã.', esperado: 'APROVADO (controle)' }
];

(async () => {
  for (const c of casos) {
    const r = await avaliarServico({ nome: c.nome, descricao: c.descricao, foco: 'educacao' });
    console.log(`#${c.n} ${c.nome} → ${r.status} ${r.categoria || ''} ${r.confianca ?? ''} | esperado: ${c.esperado}`);
    await new Promise(res => setTimeout(res, 4000));
  }
})();
