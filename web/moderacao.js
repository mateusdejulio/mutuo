// Telas da moderação por IA, compartilhadas pelas páginas de adicionar/editar
// serviço: o overlay de "verificando seu serviço" e o popup de bloqueio.
(function () {
  const estilo = document.createElement('style');
  estilo.textContent = `
    .moderacao-overlay {
      position: fixed; inset: 0; z-index: 10000;
      display: flex; align-items: center; justify-content: center;
      padding: 24px; background: rgba(0, 0, 0, 0.55);
      font-family: 'Quicksand', sans-serif;
      animation: moderacao-fade 0.2s ease;
    }
    .moderacao-card {
      width: 100%; max-width: 380px; border-radius: 24px;
      padding: 30px 24px 26px; text-align: center;
      box-shadow: 0 20px 50px rgba(0, 0, 0, 0.3);
    }
    .moderacao-card.processando { background: #3A5A40; color: #fff; }
    .moderacao-card.bloqueio { background: #E5E2D8; color: #344E41; }
    .moderacao-spinner {
      position: relative; width: 72px; height: 72px; margin: 0 auto 22px;
      display: flex; align-items: center; justify-content: center;
    }
    .moderacao-spinner::before {
      content: ''; position: absolute; inset: 0; border-radius: 50%;
      border: 3px solid rgba(255, 255, 255, 0.12); border-top-color: #E5E2D8;
      animation: moderacao-girar 1s linear infinite;
    }
    .moderacao-spinner i { font-size: 28px; color: #E5E2D8; }
    .moderacao-icone-bloqueio {
      width: 56px; height: 56px; margin: 0 auto 16px; border-radius: 50%;
      display: flex; align-items: center; justify-content: center;
      background: rgba(255, 82, 82, 0.15); color: #ff5252; font-size: 28px;
    }
    .moderacao-card h3 { margin: 0 0 8px; font-size: 1.15rem; font-weight: 700; }
    .moderacao-card.bloqueio h3 { color: #3A5A40; }
    .moderacao-card p { margin: 0; font-size: 0.85rem; line-height: 1.45; }
    .moderacao-card.processando p { color: rgba(255, 255, 255, 0.85); }
    .moderacao-motivo { margin-top: 10px !important; font-weight: 700; }
    .moderacao-apoio { margin-top: 10px !important; color: #6B705C; font-size: 0.8rem !important; }
    .moderacao-etapa {
      margin-top: 18px !important; font-size: 0.78rem !important;
      font-weight: 700; color: #E5E2D8 !important; transition: opacity 0.3s;
    }
    .moderacao-botao {
      width: 100%; margin-top: 20px; padding: 13px; border: none;
      border-radius: 14px; background: #588157; color: #fff; cursor: pointer;
      font-family: inherit; font-size: 0.95rem; font-weight: 700;
    }
    .moderacao-botao:hover { background: #3A5A40; }
    @keyframes moderacao-girar { to { transform: rotate(360deg); } }
    @keyframes moderacao-fade { from { opacity: 0; } }
  `;
  document.head.appendChild(estilo);

  const ETAPAS = [
    'Lendo as informações do serviço...',
    'Verificando as diretrizes do Mútuo...',
    'Quase pronto...',
  ];

  // Executa tarefa() (o envio pra API) com o overlay de processamento na tela.
  async function comProcessamento(tarefa) {
    const overlay = document.createElement('div');
    overlay.className = 'moderacao-overlay';
    overlay.innerHTML = `
      <div class="moderacao-card processando" role="status" aria-live="polite">
        <div class="moderacao-spinner"><i class="bi bi-stars"></i></div>
        <h3>Verificando seu serviço</h3>
        <p>Nossa IA está analisando o conteúdo para garantir que ele segue as diretrizes do Mútuo. Isso pode levar alguns segundos.</p>
        <p class="moderacao-etapa">${ETAPAS[0]}</p>
      </div>`;
    document.body.appendChild(overlay);

    const etapa = overlay.querySelector('.moderacao-etapa');
    let indice = 0;
    const timer = setInterval(() => {
      if (indice >= ETAPAS.length - 1) return clearInterval(timer);
      etapa.textContent = ETAPAS[++indice];
    }, 3000);

    try {
      return await tarefa();
    } finally {
      clearInterval(timer);
      overlay.remove();
    }
  }

  // Popup de serviço bloqueado. Resolve quando o usuário fecha.
  function mostrarBloqueio(mensagem) {
    return new Promise((resolve) => {
      const overlay = document.createElement('div');
      overlay.className = 'moderacao-overlay';
      overlay.innerHTML = `
        <div class="moderacao-card bloqueio" role="alertdialog" aria-modal="true" aria-labelledby="moderacao-titulo">
          <div class="moderacao-icone-bloqueio"><i class="bi bi-slash-circle"></i></div>
          <h3 id="moderacao-titulo">Serviço não publicado</h3>
          <p class="moderacao-motivo" hidden></p>
          <p class="moderacao-apoio">Não foi possível publicar este serviço. O conteúdo informado pode violar as diretrizes do Mútuo. Revise as informações e tente novamente.</p>
          <button type="button" class="moderacao-botao">Revisar serviço</button>
        </div>`;

      if (mensagem && String(mensagem).trim()) {
        const motivo = overlay.querySelector('.moderacao-motivo');
        motivo.textContent = String(mensagem).trim();
        motivo.hidden = false;
      }

      const fechar = () => {
        overlay.remove();
        document.removeEventListener('keydown', aoTeclar);
        resolve();
      };
      const aoTeclar = (e) => { if (e.key === 'Escape') fechar(); };

      overlay.querySelector('.moderacao-botao').addEventListener('click', fechar);
      overlay.addEventListener('click', (e) => { if (e.target === overlay) fechar(); });
      document.addEventListener('keydown', aoTeclar);

      document.body.appendChild(overlay);
      overlay.querySelector('.moderacao-botao').focus();
    });
  }

  window.MutuoModeracao = { comProcessamento, mostrarBloqueio };
})();
