(function () {
  function ongEstaLogada() {
    try {
      const ong = JSON.parse(sessionStorage.getItem('ongLogada') || '{}');
      return Boolean(ong.cnpj);
    } catch (_) {
      return false;
    }
  }

  function exigirLoginOng() {
    if (ongEstaLogada()) return true;
    window.location.replace('../login.html');
    return false;
  }

  function sairDaConta(event) {
    event?.preventDefault();
    sessionStorage.removeItem('ongLogada');
    sessionStorage.removeItem('usuarioLogado');
    window.location.replace('../login.html');
  }

  if (!exigirLoginOng()) return;
  window.addEventListener('pageshow', exigirLoginOng);

  document.addEventListener('click', event => {
    const link = event.target.closest('a');
    if (link?.textContent.trim().includes('Sair da conta')) sairDaConta(event);
  });

  const nav = document.querySelector('body > nav');
  if (!nav || nav.querySelector('.ong-nav-hamburger')) return;

  // O perfil possuía uma implementação própria; ao usar o componente
  // compartilhado, remove apenas os elementos visuais antigos.
  const hamburgerAntigo = nav.querySelector('.nav-hamburger');
  if (hamburgerAntigo) hamburgerAntigo.remove();
  document.getElementById('mobileDrawer')?.remove();
  document.getElementById('drawerOverlay')?.remove();

  const paginaAtual = decodeURIComponent(location.pathname.split('/').pop() || '');
  const itens = [
    ['homeOngMutuo.html', 'bi-house-fill', 'Início'],
    ['chatOng.html', 'bi-chat-dots-fill', 'Chat'],
    ['notificacoesOng.html', 'bi-bell-fill', 'Notificações'],
    ['perfilOngGMutuo.html', 'bi-person-fill', 'Meu perfil'],
    ['planosOng.html', 'bi-gem', 'Conheça nossos planos'],
    ['certificadosOng.html', 'bi-award', 'Certificados'],
    ['contatoOng.html', 'bi-envelope', 'Contato'],
    ['comoUsarOng.html', 'bi-question-circle', 'Como usar a plataforma'],
    ['quemSomosOng.html', 'bi-people', 'Quem somos']
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

  let ong = {};
  try { ong = JSON.parse(sessionStorage.getItem('ongLogada') || '{}'); } catch (_) {}

  const perfil = document.createElement('div');
  perfil.className = 'ong-drawer-profile';
  perfil.innerHTML = '<img alt="Perfil da ONG"><div><strong></strong><small>Conta de ONG</small></div>';
  perfil.querySelector('img').src = ong.foto_perfil
    ? `https://mutuo-api.onrender.com/uploads/fotos/${ong.foto_perfil}`
    : '../imagens/mutuoLogo.png';
  perfil.querySelector('strong').textContent = ong.nomeOng || 'Minha ONG';
  drawer.appendChild(perfil);

  itens.forEach((item, indice) => {
    if (indice === 0 || indice === 4) {
      const label = document.createElement('span');
      label.className = 'ong-drawer-label';
      label.textContent = indice === 0 ? 'Menu' : 'Mais opções';
      drawer.appendChild(label);
    }

    const link = document.createElement('a');
    link.href = item[0];
    link.className = 'ong-drawer-link';
    if (paginaAtual === item[0]) link.classList.add('active');
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
