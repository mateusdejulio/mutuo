// Camada 1 — validações locais/spam óbvio, sem custo e sem chamar IA.
// Roda ANTES da Camada 2 pra economizar chamadas em casos evidentes.

const TAMANHO_MINIMO_DESCRICAO = 8;

// Repetição excessiva de um mesmo caractere (ex: "aaaaaaaaaa")
function temRepeticaoExcessiva(texto) {
  return /(.)\1{9,}/.test(texto);
}

// Bloco de maiúsculas muito longo (comum em spam)
function temCapsLockExcessivo(texto) {
  const letras = texto.replace(/[^a-zA-ZÀ-ÿ]/g, '');
  if (letras.length < 15) return false;
  const maiusculas = letras.replace(/[^A-ZÀ-Ý]/g, '');
  return maiusculas.length / letras.length > 0.8;
}

/**
 * @param {{ nome: string, descricao: string }} campos
 * @returns {{ bloqueado: boolean, motivo: string|null }}
 */
function validarRegrasLocais({ nome, descricao }) {
  const nomeLimpo = (nome || '').trim();
  const descricaoLimpa = (descricao || '').trim();

  if (!nomeLimpo || !descricaoLimpa) {
    return { bloqueado: true, motivo: 'Nome ou descrição vazios.' };
  }
  if (descricaoLimpa.length < TAMANHO_MINIMO_DESCRICAO) {
    return { bloqueado: true, motivo: 'Descrição curta demais para ser avaliada.' };
  }
  if (temRepeticaoExcessiva(nomeLimpo) || temRepeticaoExcessiva(descricaoLimpa)) {
    return { bloqueado: true, motivo: 'Padrão de spam detectado (repetição excessiva de caracteres).' };
  }
  if (temCapsLockExcessivo(descricaoLimpa)) {
    return { bloqueado: true, motivo: 'Padrão de spam detectado (texto em caixa alta).' };
  }
  return { bloqueado: false, motivo: null };
}

module.exports = { validarRegrasLocais };
