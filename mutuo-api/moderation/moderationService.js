// Orquestra a moderação: Camada 1 (rules.js) + Camada 2 (Gemini API).
// Camada 3 ainda não existe — ver policy.js.

const { validarRegrasLocais } = require('./rules');

// Modelo principal + reserva (usado quando o principal está sobrecarregado,
// sem cota ou indisponível). gemini-2.5-flash saiu de linha para chaves novas.
const GEMINI_MODELOS = ['gemini-3.6-flash', 'gemini-3.1-flash-lite'];
const urlDoModelo = (modelo) => `https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent`;
// Modelos 3.x "pensam" antes de responder; com imagem passam fácil de 8 s.
const TIMEOUT_MS = 20000;
const ESPERA_RETRY_MS = 1500;
// Erros em que vale tentar de novo / trocar de modelo (sobrecarga, cota, modelo indisponível)
const STATUS_TROCA_MODELO = [404, 429, 500, 503];

// Categorias que o prompt pode retornar nesta fase (segurança geral —
// NÃO inclui fraude/documento falso, isso é Camada 3).
const CATEGORIAS_VALIDAS = [
  'VIOLENCIA', 'SEXUAL', 'EXPLORACAO', 'DISCRIMINACAO', 'PERIGOSO', 'ILICITO'
];
const STATUS_VALIDOS = ['APROVADO', 'REVISAO', 'BLOQUEADO'];

const PROMPT_SISTEMA = `Você é um moderador de conteúdo da plataforma Mútuo, um
app brasileiro de troca de serviços voluntários entre usuários e ONGs.

Analise o nome, a descrição e a imagem (se houver) de um serviço que alguém
quer publicar. Você deve avaliar SOMENTE segurança geral — categorias:
VIOLENCIA, SEXUAL, EXPLORACAO (menores), DISCRIMINACAO (ódio/assédio),
PERIGOSO (automutilação/incitação a risco), ILICITO (atividade criminosa
óbvia e explícita). NÃO tente avaliar fraude, golpe ou falsificação de
documentos — isso não é escopo desta análise e não deve influenciar sua
decisão nesta fase.

Filosofia de decisão:
- Violação clara e evidente nas categorias acima → BLOQUEADO
- Caso ambíguo ou não tem certeza → REVISAO (prefira isso a bloquear um
  serviço legítimo por engano)
- Conteúdo normal, sem nenhuma das categorias acima → APROVADO

Responda APENAS com um JSON válido, sem markdown, sem texto fora do JSON,
neste formato exato:
{
  "status": "APROVADO" | "REVISAO" | "BLOQUEADO",
  "categoria": null | "VIOLENCIA" | "SEXUAL" | "EXPLORACAO" | "DISCRIMINACAO" | "PERIGOSO" | "ILICITO",
  "confianca": número entre 0 e 1,
  "motivo": null ou string curta explicando o motivo,
  "mensagemUsuario": null ou uma mensagem curta e educada para mostrar ao usuário
}`;

async function comTimeout(promiseFn, ms) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  try {
    return await promiseFn(controller.signal);
  } finally {
    clearTimeout(timer);
  }
}

function validarRespostaGemini(objeto) {
  if (!objeto || typeof objeto !== 'object') return false;
  if (!STATUS_VALIDOS.includes(objeto.status)) return false;
  if (objeto.categoria !== null && !CATEGORIAS_VALIDAS.includes(objeto.categoria)) return false;
  if (typeof objeto.confianca !== 'number' || objeto.confianca < 0 || objeto.confianca > 1) return false;
  return true;
}

/**
 * Uma chamada a um modelo específico. Nunca lança erro — retorna
 * { erro: true, causa, httpStatus? } ou { erro: false, ...resposta }.
 */
async function chamarModelo(modelo, parts) {
  try {
    const resposta = await comTimeout((signal) => fetch(urlDoModelo(modelo), {
      method: 'POST',
      signal,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': process.env.GEMINI_API_KEY
      },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: { responseMimeType: 'application/json', temperature: 0 }
      })
    }), TIMEOUT_MS);

    if (!resposta.ok) {
      // Mensagem de erro do Google (não contém a chave) ajuda a diagnosticar nos logs do Render
      const corpo = await resposta.text().catch(() => '');
      let mensagem = '';
      try { mensagem = JSON.parse(corpo).error?.message || ''; } catch (e) { /* corpo não-JSON */ }
      console.error(`Gemini (${modelo}) respondeu HTTP ${resposta.status}:`, mensagem.slice(0, 200));
      return { erro: true, httpStatus: resposta.status, causa: `HTTP ${resposta.status}` };
    }

    const dados = await resposta.json();
    // Modelos com raciocínio podem mandar partes de "pensamento" antes da resposta
    const textoResposta = (dados.candidates?.[0]?.content?.parts || [])
      .find(p => typeof p.text === 'string' && !p.thought)?.text;
    if (!textoResposta) {
      console.error(`Gemini (${modelo}) respondeu sem texto. finishReason:`, dados.candidates?.[0]?.finishReason);
      return { erro: true, causa: 'resposta vazia' };
    }

    let objeto;
    try {
      objeto = JSON.parse(textoResposta);
    } catch (e) {
      console.error(`Gemini (${modelo}) retornou texto que não é JSON.`);
      return { erro: true, causa: 'resposta não é JSON' };
    }
    if (!validarRespostaGemini(objeto)) {
      console.error(`Gemini (${modelo}) retornou JSON fora do formato esperado.`);
      return { erro: true, causa: 'JSON fora do formato' };
    }

    return { erro: false, ...objeto };
  } catch (err) {
    const causa = err.name === 'AbortError' ? `timeout de ${TIMEOUT_MS / 1000}s` : 'falha de rede';
    console.error(`Falha ao chamar Gemini (${modelo}):`, err.message);
    return { erro: true, causa };
  }
}

/**
 * Chama o Gemini com o texto do serviço e, opcionalmente, a imagem.
 * 503 no modelo principal: 1 nova tentativa. Persistindo (ou 404/429/500/timeout),
 * tenta o modelo reserva. Nunca lança erro pro chamador — retorna { erro: true, causa }
 * pra quem chamou decidir o fallback (ver avaliarServico).
 */
async function chamarGemini({ texto, imagemBuffer, imagemMime }) {
  if (!process.env.GEMINI_API_KEY) {
    console.error('GEMINI_API_KEY não configurada no ambiente.');
    return { erro: true, causa: 'GEMINI_API_KEY não configurada' };
  }

  const parts = [{ text: `${PROMPT_SISTEMA}\n\nServiço a analisar:\n${texto}` }];
  if (imagemBuffer) {
    parts.push({
      inlineData: {
        mimeType: imagemMime || 'image/jpeg',
        data: imagemBuffer.toString('base64')
      }
    });
  }

  const causas = [];
  for (const modelo of GEMINI_MODELOS) {
    let r = await chamarModelo(modelo, parts);
    if (r.erro && r.httpStatus === 503) {
      await new Promise(res => setTimeout(res, ESPERA_RETRY_MS));
      r = await chamarModelo(modelo, parts);
    }
    if (!r.erro) return { ...r, modelo };

    causas.push(`${modelo}: ${r.causa}`);
    // Erros que não se resolvem trocando de modelo (ex.: 400 chave inválida, 403) param aqui
    const trocaResolve = r.httpStatus === undefined || STATUS_TROCA_MODELO.includes(r.httpStatus);
    if (!trocaResolve) break;
  }
  return { erro: true, causa: causas.join('; ') };
}

function registrarLog(origem, r, modelo = null) {
  // Sem texto do serviço, sem chave. Útil pra diagnóstico e pro TCC.
  console.log('[moderacao]', JSON.stringify({
    origem, modelo, status: r.status, categoria: r.categoria,
    confianca: r.confianca, motivo: origem === 'gemini' ? undefined : r.motivo,
    data: new Date().toISOString()
  }));
}

/**
 * Ponto de entrada único. Sempre retorna:
 * { status: 'APROVADO'|'REVISAO'|'BLOQUEADO', categoria, confianca, motivo, mensagemUsuario }
 *
 * @param {{ nome: string, descricao: string, foco: string, imagemBuffer?: Buffer, imagemMime?: string }} servico
 */
async function avaliarServico({ nome, descricao, foco, imagemBuffer, imagemMime }) {
  // Camada 1 — sem custo, resolve os casos óbvios sem chamar a IA.
  const local = validarRegrasLocais({ nome, descricao });
  if (local.bloqueado) {
    const r = {
      status: 'BLOQUEADO',
      categoria: 'SPAM',
      confianca: 1,
      motivo: local.motivo,
      mensagemUsuario: 'Este serviço não atende às diretrizes de publicação do Mútuo.'
    };
    registrarLog('regras-locais', r);
    return r;
  }

  // Camada 2 — Gemini (texto + imagem, se houver).
  const texto = `Nome do serviço: ${nome}\nDescrição: ${descricao}\nÁrea/foco: ${foco || ''}`;
  const resultado = await chamarGemini({ texto, imagemBuffer, imagemMime });

  if (resultado.erro) {
    // IA indisponível: nunca publica automaticamente sem checagem.
    const r = {
      status: 'REVISAO',
      categoria: null,
      confianca: null,
      // A causa aparece na tela "Revisão" do Electron (ajuda a diagnosticar)
      motivo: `Verificação automática indisponível no momento do cadastro (${resultado.causa}).`,
      mensagemUsuario: 'Seu serviço foi enviado para análise antes da publicação.'
    };
    registrarLog('fallback-ia-indisponivel', r);
    return r;
  }

  const r = {
    status: resultado.status,
    categoria: resultado.categoria,
    confianca: resultado.confianca,
    motivo: resultado.motivo,
    mensagemUsuario: resultado.mensagemUsuario
      || (resultado.status === 'BLOQUEADO'
        ? 'Este serviço não atende às diretrizes de publicação do Mútuo.'
        : resultado.status === 'REVISAO'
          ? 'Seu serviço foi enviado para análise antes da publicação.'
          : null)
  };
  registrarLog('gemini', r, resultado.modelo);
  return r;
}

module.exports = { avaliarServico };
