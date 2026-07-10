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

  atualizarTodasFotos(URL.createObjectURL(arquivo)); // preview imediato

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

  atualizarTodasFotosOng(URL.createObjectURL(arquivo)); // preview imediato

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