// web/chat-socket.js
// Conexão única de socket por página + helpers de chat, no mesmo padrão do
// chat_socket_service.dart do mobile.

const MutuoChat = (() => {
  let socket = null;
  let contaAtual = null; // { tipo, id }

  function contaLogada() {
    const usuario = JSON.parse(sessionStorage.getItem('usuarioLogado') || 'null');
    if (usuario?.cpf) return { tipo: 'usuario', id: usuario.cpf };
    const ong = JSON.parse(sessionStorage.getItem('ongLogada') || 'null');
    if (ong?.cnpj) return { tipo: 'ong', id: ong.cnpj };
    return null;
  }

  function conectar() {
    contaAtual = contaLogada();
    if (!contaAtual) return null;
    if (!socket) {
      socket = io(API_URL, { transports: ['websocket', 'polling'] });
      socket.on('connect', () => {
        socket.emit('identificar', contaAtual);
      });
    }
    return socket;
  }

  function enviarMensagem(conversaId, conteudo) {
    if (!socket || !contaAtual) return;
    socket.emit('mensagem:enviar', {
      conversaId,
      tipo: contaAtual.tipo,
      id: contaAtual.id,
      conteudo
    });
  }

  function marcarComoLida(conversaId) {
    if (!socket || !contaAtual) return;
    socket.emit('conversa:lida', { conversaId, tipo: contaAtual.tipo, id: contaAtual.id });
  }

  function onMensagemNova(cb) { conectar(); socket && socket.on('mensagem:nova', cb); }
  function onMensagemEnviada(cb) { conectar(); socket && socket.on('mensagem:enviada', cb); }
  function onConversaLida(cb) { conectar(); socket && socket.on('conversa:lida', cb); }

  // ── Badge de não lidas na navbar (link "Chat") ──
  async function atualizarBadgeChat() {
    const conta = contaLogada();
    if (!conta) return;
    try {
      const resp = await fetch(`${API_URL}/conversas/${conta.tipo}/${encodeURIComponent(conta.id)}`);
      const conversas = await resp.json();
      const total = Array.isArray(conversas)
        ? conversas.reduce((soma, c) => soma + (Number(c.naoLidas) || 0), 0)
        : 0;
      document.querySelectorAll('.chat-badge').forEach(badge => {
        if (total > 0) {
          badge.textContent = total;
          badge.style.display = '';
        } else {
          badge.style.display = 'none';
        }
      });
    } catch (erro) {
      console.error('Erro ao atualizar badge do chat:', erro);
    }
  }

  document.addEventListener('DOMContentLoaded', () => {
    if (!contaLogada()) return;
    conectar();
    atualizarBadgeChat();
    onMensagemNova(atualizarBadgeChat);
    onConversaLida(atualizarBadgeChat);
  });

  return {
    conectar, enviarMensagem, marcarComoLida,
    onMensagemNova, onMensagemEnviada, onConversaLida,
    atualizarBadgeChat, contaLogada
  };
})();
