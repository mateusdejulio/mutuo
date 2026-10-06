// Camada 3 (regras específicas do Mútuo) — AINDA NÃO IMPLEMENTADA.
// Quando for implementada, este arquivo deve exportar as categorias
// próprias da plataforma (FRAUDE, DROGAS, ARMAS, PIRATARIA, etc.) e o
// texto da política que será enviado ao modelo para classificação
// contextual. Por enquanto, moderationService.js não chama nada daqui.

const CATEGORIAS_MUTUO = [
  'ILICITO', 'FRAUDE', 'DROGAS', 'ARMAS', 'SEXUAL', 'VIOLENCIA',
  'EXPLORACAO', 'PERIGOSO', 'DISCRIMINACAO', 'SPAM', 'PIRATARIA',
  'FORA_DO_ESCOPO', 'OUTROS'
];

module.exports = { CATEGORIAS_MUTUO };
