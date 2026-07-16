const API_URL = 'http://localhost:3000';

function atualizarTodasFotos(url) {
  ['fotoTopo','fotoNavbarTopo', 'fotoPerfil', 'fotoDrawer'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.src = url;
  });
}

async function carregarFoto() {
  const usuario = JSON.parse(sessionStorage.getItem('usuarioLogado') || '{}');

  if (!usuario.cpf) return;

  try {
    const res  = await fetch(`${API_URL}/perfil/foto/${usuario.cpf}`);
    const data = await res.json();

    if (data.fotoPerfil) {
      atualizarTodasFotos(API_URL + data.fotoPerfil);
    }
  } catch (e) {
    console.error('Erro ao carregar foto:', e);
  }
}


const _usuario = JSON.parse(sessionStorage.getItem('usuarioLogado') || '{}');
if (_usuario.nome) {
  const elNome = document.getElementById('nomeUsuario');
  if (elNome) elNome.textContent = _usuario.nome;
}
carregarFoto();


  async function enviarFoto(input) {
  const arquivo = input.files[0];
  if (!arquivo) return;

  atualizarTodasFotos(URL.createObjectURL(arquivo)); 

  const usuario = JSON.parse(sessionStorage.getItem('usuarioLogado') || '{}');
  if (!usuario.cpf) return alert('Sessão expirada.');

  const formData = new FormData();
  formData.append('cpf', usuario.cpf);
  formData.append('fotoPerfil', arquivo);

  try {
    const res  = await fetch(`${API_URL}/perfil/foto`, { method: 'POST', body: formData });
    const data = await res.json();
    if (!data.sucesso) alert('Erro: ' + (data.erro || 'falha no upload'));
  } catch (e) {
    alert('Falha ao enviar a foto.');
  }
}


function atualizarTodasFotosOng(url) {
  ['fotoTopo', 'fotoNavbarTopo', 'fotoPerfil', 'fotoDrawer'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.src = url;
  });
}

async function carregarFotoOng() {
  const ong = JSON.parse(sessionStorage.getItem('ongLogada') || '{}');

  if (!ong.cnpj) return;

  try {
    const res  = await fetch(`${API_URL}/perfil/fotoOng/${ong.cnpj}`);
    const data = await res.json();

    if (data.fotoPerfil) {
      atualizarTodasFotosOng(API_URL + data.fotoPerfil);
    }
  } catch (e) {
    console.error('Erro ao carregar foto:', e);
  }
}

carregarFotoOng();

async function enviarFotoOng(input) {
  const arquivo = input.files[0];
  if (!arquivo) return;

  atualizarTodasFotosOng(URL.createObjectURL(arquivo)); 

  const ong = JSON.parse(sessionStorage.getItem('ongLogada') || '{}');
  if (!ong.cnpj) return alert('Sessão expirada.');

  const formData = new FormData();
  formData.append('cnpj', ong.cnpj);
  formData.append('fotoPerfil', arquivo);

  try {
    const res  = await fetch(`${API_URL}/perfil/fotoOng`, { method: 'POST', body: formData });
    const data = await res.json();
    if (!data.sucesso) alert('Erro: ' + (data.erro || 'falha no upload'));
  } catch (e) {
    alert('Falha ao enviar a foto.');
  }
}
// ===== Navbar da ONG (nome e foto) =====

function pegarOngLogada() {
  const raw = sessionStorage.getItem('ongLogada');
  if (!raw) return null;
  try { return JSON.parse(raw); } catch { return null; }
}

function urlDaFoto(nomeArquivo, nomeOngFallback) {
  if (nomeArquivo) return `${API_URL}/uploads/fotos/${nomeArquivo}`;
  return '../imagens/mutuoLogo.png';
}

function aplicarFotoEmTodosOsLugares(nomeArquivo, nomeOngFallback) {
  const url = urlDaFoto(nomeArquivo, nomeOngFallback);
  ['navFotoPerfil', 'drawerFotoPerfil'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.src = url;
  });
}

async function carregarNavOng() {
  const logada = pegarOngLogada();
  if (!logada || !logada.cnpj) {
    window.location.href = '../login.html';
    return;
  }

  const navNome = document.getElementById('navNomeOng');
  const drawerNome = document.getElementById('drawerNomeOng');

  if (navNome) navNome.textContent = logada.nomeOng || 'ONG';
  if (drawerNome) drawerNome.textContent = logada.nomeOng || 'ONG';
  aplicarFotoEmTodosOsLugares(logada.foto_perfil, logada.nomeOng);

  try {
    const resposta = await fetch(`${API_URL}/ongs/${encodeURIComponent(logada.cnpj)}`);
    if (!resposta.ok) throw new Error('Não foi possível carregar os dados da ONG.');

    const ong = await resposta.json();

    if (navNome) navNome.textContent = ong.nomeOng || 'ONG';
    if (drawerNome) drawerNome.textContent = ong.nomeOng || 'ONG';
    aplicarFotoEmTodosOsLugares(ong.foto_perfil, ong.nomeOng);

    sessionStorage.setItem('ongLogada', JSON.stringify({
      ...logada,
      nomeOng: ong.nomeOng,
      email: ong.email,
      foco: ong.foco,
      premium: ong.premium,
      foto_perfil: ong.foto_perfil
    }));

  } catch (erro) {
    console.error(erro);
  }
}