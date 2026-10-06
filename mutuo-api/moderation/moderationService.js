// Orquestra a moderação: Camada 1 (rules.js) + Camada 2 (Gemini API).
// Camada 3 ainda não existe — ver policy.js.

const { validarRegrasLocais } = require('./rules');

const GEMINI_MODEL = 'gemini-3.6-flash'; // gemini-2.5-flash saiu de linha para chaves novas
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
const TIMEOUT_MS = 8000;
const ESPERA_RETRY_MS = 1500;

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
 * Chama o Gemini com o texto do serviço e, opcionalmente, a imagem.
 * Nunca lança erro pro chamador — retorna { erro: true } pra quem chamou
 * decidir o fallback (ver avaliarServico).
 */
async function chamarGemini({ texto, imagemBuffer, imagemMime }, tentativa = 1) {
  const parts = [{ text: `${PROMPT_SISTEMA}\n\nServiço a analisar:\n${texto}` }];
  if (imagemBuffer) {
    parts.push({
      inlineData: {
        mimeType: imagemMime || 'image/jpeg',
        data: imagemBuffer.toString('base64')
      }
    });
  }

  try {
    const resposta = await comTimeout((signal) => fetch(GEMINI_URL, {
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
      console.error('Gemini API respondeu erro HTTP:', resposta.status);
      // 503 costuma ser passageiro: uma nova tentativa. 429 (limite) NÃO repete — vai pra REVISAO.
      if (resposta.status === 503 && tentativa < 2) {
        await new Promise(r => setTimeout(r, ESPERA_RETRY_MS));
        return chamarGemini({ texto, imagemBuffer, imagemMime }, tentativa + 1);
      }
      return { erro: true };
    }

    const dados = await resposta.json();
    const textoResposta = dados.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!textoResposta) return { erro: true };

    const objeto = JSON.parse(textoResposta);
    if (!validarRespostaGemini(objeto)) {
      console.error('Gemini retornou JSON fora do formato esperado.');
      return { erro: true };
    }

    return { erro: false, ...objeto };
  } catch (err) {
    console.error('Falha ao chamar Gemini API:', err.message);
    return { erro: true };
  }
}

function registrarLog(origem, r) {
  // Sem texto do serviço, sem chave. Útil pra diagnóstico e pro TCC.
  console.log('[moderacao]', JSON.stringify({
    origem, modelo: GEMINI_MODEL, status: r.status, categoria: r.categoria,
    confianca: r.confianca, data: new Date().toISOString()
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
      motivo: 'Verificação automática indisponível no momento do cadastro.',
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
  registrarLog('gemini', r);
  return r;
}

module.exports = { avaliarServico };
