const API_URL = 'http://localhost:3000';

function atualizarTodasFotos(url) {
  ['fotoNavbarTopo', 'fotoPerfil', 'fotoDrawer'].forEach(id => {
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

