const API_URL = 'http://localhost:3000';

function atualizarTodasFotos(url) {
  ['fotoNavbarTopo', 'fotoPerfil', 'fotoDrawer'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.src = url;
  });
}

async function carregarFoto() {
  const usuario = JSON.parse(localStorage.getItem('usuarioMutuo') || '{}');

  if (usuario.fotoPerfil) {
    atualizarTodasFotos(API_URL + usuario.fotoPerfil);
    return;
  }

  if (!usuario.cpf) return;

  try {
    const res  = await fetch(`${API_URL}/perfil/foto/${usuario.cpf}`);
    const data = await res.json();

    if (data.fotoPerfil) {
      atualizarTodasFotos(API_URL + data.fotoPerfil);
      usuario.fotoPerfil = data.fotoPerfil;
      localStorage.setItem('usuarioMutuo', JSON.stringify(usuario));
    }
  } catch (e) {
    console.error('Erro ao carregar foto:', e);
  }
}

carregarFoto();