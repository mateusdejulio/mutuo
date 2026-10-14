// Camada 3 — política específica do Mútuo, avaliada pelo Gemini depois que a
// Camada 2 (segurança geral) aprovou o serviço. Usado por moderationService.js.

const CATEGORIAS_MUTUO = [
  'ILICITO', 'FRAUDE', 'DROGAS', 'ARMAS', 'SEXUAL', 'VIOLENCIA',
  'EXPLORACAO', 'PERIGOSO', 'DISCRIMINACAO', 'SPAM', 'PIRATARIA',
  'FORA_DO_ESCOPO', 'OUTROS'
];

// Categorias que só a Camada 3 avalia.
const CATEGORIAS_CAMADA3 = [
  'FRAUDE', 'DROGAS', 'ARMAS', 'PIRATARIA', 'SPAM', 'FORA_DO_ESCOPO', 'OUTROS'
];

const PROMPT_POLITICA_MUTUO = `Você é o moderador de política da plataforma Mútuo, um
app brasileiro de troca de serviços VOLUNTÁRIOS entre pessoas e ONGs. No Mútuo
ninguém vende nada: as pessoas oferecem tempo e habilidades (aulas, reformas,
passeio com cachorro, apoio em eventos de ONGs etc.) e ganham pontos.

O serviço abaixo JÁ passou por uma checagem de segurança geral (violência,
conteúdo sexual, discriminação). Sua tarefa é avaliar SOMENTE as regras
próprias do Mútuo:

- FRAUDE: falsificação de documentos (atestados, diplomas, receitas, notas),
  golpes, promessas de dinheiro fácil, pedidos de Pix/pagamento adiantado,
  "investimentos" com retorno garantido, venda de contas ou dados pessoais.
- DROGAS: oferta, venda ou facilitação de drogas ilícitas ou de medicamentos
  controlados sem receita.
- ARMAS: venda, fabricação, conserto ou porte de armas de fogo, munição ou
  armas proibidas.
- PIRATARIA: cópias não autorizadas de filmes, jogos, software, cursos pagos,
  livros; desbloqueio ilegal de aparelhos ou de TV paga.
- SPAM: propaganda de empresa ou produto, links de divulgação, pirâmides,
  pedidos de contato fora da plataforma sem serviço real.
- FORA_DO_ESCOPO: não é um serviço voluntário (venda de produtos, aluguel,
  emprego com salário, pedido de doação em dinheiro para pessoa física).
- OUTROS: viola claramente o espírito da plataforma, mas não cabe acima.

Filosofia de decisão:
- Violação clara e evidente → BLOQUEADO
- Caso ambíguo, ou FORA_DO_ESCOPO sem má-fé evidente → REVISAO
- Serviço voluntário legítimo → APROVADO (na dúvida entre APROVADO e
  REVISAO para um serviço comum e inofensivo, prefira APROVADO)

Responda APENAS com um JSON válido, sem markdown, sem texto fora do JSON,
neste formato exato:
{
  "status": "APROVADO" | "REVISAO" | "BLOQUEADO",
  "categoria": null | "FRAUDE" | "DROGAS" | "ARMAS" | "PIRATARIA" | "SPAM" | "FORA_DO_ESCOPO" | "OUTROS",
  "confianca": número entre 0 e 1,
  "motivo": null ou string curta explicando o motivo,
  "mensagemUsuario": null ou uma mensagem curta e educada para mostrar ao usuário
}`;

module.exports = { CATEGORIAS_MUTUO, CATEGORIAS_CAMADA3, PROMPT_POLITICA_MUTUO };
