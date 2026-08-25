(function () {
  const nav = document.querySelector('body > nav');
  if (!nav || nav.querySelector('.ong-nav-hamburger')) return;

  const hamburgerAntigo = nav.querySelector('.nav-hamburger');
  if (hamburgerAntigo) hamburgerAntigo.remove();
  document.getElementById('mobileDrawer')?.remove();
  document.getElementById('drawerOverlay')?.remove();

  const paginaAtual = decodeURIComponent(location.pathname.split('/').pop() || '');
  const itens = [
    ['homeMutuo.html', 'bi-house-fill', 'Início'],
    ['serviçosMutuo.html', 'bi-grid-fill', 'Serviços'],
    ['OngsMutuo.html', 'bi-heart-fill', 'ONGs'],
    ['chatMutuo.html', 'bi-chat-dots-fill', 'Chat'],
    ['notificacoesMutuo.html', 'bi-bell-fill', 'Notificações'],
    ['perfilMutuo.html', 'bi-person-fill', 'Meu perfil'],
    ['planosMutuo.html', 'bi-gem', 'Conheça nossos planos'],
    ['certificadosMutuo.html', 'bi-award', 'Certificados'],
    ['contatoMutuo.html', 'bi-envelope', 'Contato'],
    ['comoUsarMutuo.html', 'bi-question-circle', 'Como usar a plataforma'],
    ['quemSomosMutuo.html', 'bi-people', 'Quem somos']
  ];

  const botao = document.createElement('button');
  botao.type = 'button';
  botao.className = 'ong-nav-hamburger';
  botao.setAttribute('aria-label', 'Abrir menu');
  botao.setAttribute('aria-expanded', 'false');
  botao.innerHTML = '<span></span><span></span><span></span>';
  nav.appendChild(botao);

  const overlay = document.createElement('div');
  overlay.className = 'ong-drawer-overlay';

  const drawer = document.createElement('aside');
  drawer.className = 'ong-mobile-drawer';
  drawer.setAttribute('aria-hidden', 'true');

  let usuario = {};
  try { usuario = JSON.parse(sessionStorage.getItem('usuarioLogado') || '{}'); } catch (_) {}

  const perfil = document.createElement('div');
  perfil.className = 'ong-drawer-profile';
  perfil.innerHTML = '<img alt="Perfil do usuário"><div><strong></strong><small>Conta de usuário</small></div>';
  perfil.querySelector('img').src = usuario.foto_perfil
    ? `https://mutuo-api.onrender.com/uploads/fotos/${usuario.foto_perfil}`
    : '../imagens/mutuoLogo.png';
  perfil.querySelector('strong').textContent = usuario.nome || 'Meu perfil';
  drawer.appendChild(perfil);

  itens.forEach((item, indice) => {
    if (indice === 0 || indice === 6) {
      const label = document.createElement('span');
      label.className = 'ong-drawer-label';
      label.textContent = indice === 0 ? 'Menu' : 'Mais opções';
      drawer.appendChild(label);
    }

    const link = document.createElement('a');
    link.href = item[0];
    link.className = 'ong-drawer-link';
    const ehOngs = item[0] === 'OngsMutuo.html' && paginaAtual === 'perfilOngMutuo.html';
    if (paginaAtual === item[0] || ehOngs) link.classList.add('active');
    link.innerHTML = `<i class="bi ${item[1]}"></i><span></span>`;
    link.querySelector('span').textContent = item[2];
    drawer.appendChild(link);
  });

  const sair = document.createElement('a');
  sair.href = '../login.html';
  sair.className = 'ong-drawer-link danger';
  sair.innerHTML = '<i class="bi bi-box-arrow-right"></i><span>Sair da conta</span>';
  drawer.appendChild(sair);
  document.body.append(overlay, drawer);

  function fechar() {
    botao.classList.remove('open');
    overlay.classList.remove('open');
    drawer.classList.remove('open');
    document.body.classList.remove('ong-menu-aberto');
    botao.setAttribute('aria-expanded', 'false');
    drawer.setAttribute('aria-hidden', 'true');
  }

  function abrir() {
    botao.classList.add('open');
    overlay.classList.add('open');
    drawer.classList.add('open');
    document.body.classList.add('ong-menu-aberto');
    botao.setAttribute('aria-expanded', 'true');
    drawer.setAttribute('aria-hidden', 'false');
  }

  botao.addEventListener('click', () => drawer.classList.contains('open') ? fechar() : abrir());
  overlay.addEventListener('click', fechar);
  drawer.querySelectorAll('a').forEach(link => link.addEventListener('click', fechar));
  document.addEventListener('keydown', event => { if (event.key === 'Escape') fechar(); });
  window.addEventListener('resize', () => { if (window.innerWidth > 768) fechar(); });
})();
