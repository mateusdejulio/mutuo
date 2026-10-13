console.log("MAIN.JS FOI EXECUTADO");
process.on('uncaughtException', (err) => {
  console.error('ERRO NÃO TRATADO:');
  console.error(err);
});

process.on('unhandledRejection', (err) => {
  console.error('PROMISE REJEITADA:');
  console.error(err);
});

//console.log("Processo principal")

// importações
const { app, BrowserWindow, ipcMain } = require('electron')
const path = require('node:path')
//const db = require('./mutuo-api/db');
/*const API_URL = process.env.NODE_ENV === 'production'
? 'https://mutuo-api.onrender.com'
: 'http://localhost:3000';*/

const API_URL = 'https://mutuo-api.onrender.com';

//variáveis
let win;
let inicio;
// Token do admin devolvido pelo /login. Fica só na memória do processo
// principal: as páginas não têm acesso a ele.
let tokenAdm = null;

// janela login
const createWindow = () => {
  win = new BrowserWindow({
    width: 800,
    height: 600,
    icon: './src/public/img/mutuo.png',
     webPreferences: {
      preload: path.join(__dirname, 'preload.js')
    },
    contextIsolation: true,
    nodeIntegration: false,
    //resizable: false,
    autoHideMenuBar: true
  })

  win.maximize()
  //win.webContents.openDevTools()

  win.setResizable(true)
  win.on('will-resize', (event) => {
    event.preventDefault()
  })

  win.loadFile('./src/views/index.html')
  .catch(err => console.error(err));
}

//janela inicio
const inicioWindow = () => {
  inicio = new BrowserWindow({
    width: 800,
    height: 600,
    icon: './src/public/img/mutuo.png',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js')
    },
    contextIsolation: true,
    nodeIntegration: false,
    //resizable: false,
    autoHideMenuBar: true
  })

  inicio.maximize()
  

  inicio.setResizable(true)
  inicio.on('will-resize', (event) => {
    event.preventDefault()
  })

  inicio.loadFile('./src/views/inicio.html')
}

// função banco de dados
// Helper para facilitar o fetch
async function apiFetch(endpoint, method = 'GET', body = null) {
    const options = {
        method,
        headers: { 'Content-Type': 'application/json' }
    };
    if (tokenAdm) options.headers.Authorization = `Bearer ${tokenAdm}`;
    if (body) options.body = JSON.stringify(body);
    const response = await fetch(`${API_URL}${endpoint}`, options);
    // Token expirado ou inválido: volta para a tela de login.
    if (response.status === 401 && endpoint !== '/login') {
        voltarParaLogin();
    }
    return await response.json();
}

function voltarParaLogin() {
  tokenAdm = null;
  if (win && !win.isDestroyed()) return;
  createWindow();
  if (inicio && !inicio.isDestroyed()) inicio.close();
}

ipcMain.handle('validar-login', async (e, login, senha) => {
  const resposta = await apiFetch('/login', 'POST', { login, senha });
  tokenAdm = resposta.sucesso ? resposta.token : null;
  return !!resposta.sucesso;
});

ipcMain.handle('buscar-usuarios', () => apiFetch('/usuarios'));

ipcMain.handle('total-usuarios', () => apiFetch('/stats/usuarios'));

ipcMain.handle('total-ongs', () => apiFetch('/stats/ongs'));

ipcMain.handle('total-servicos', () => apiFetch('/stats/servicos'));

ipcMain.handle('total-horas', () => apiFetch('/stats/horas'));

ipcMain.handle('total-usuarios-inativos', () => apiFetch('/stats/usuarios-inativos'));

ipcMain.handle('total-pontos', () => apiFetch('/stats/pontos'));

ipcMain.handle('total-ongs-inativas', () => apiFetch('/stats/ongs-inativas'));

ipcMain.handle('total-premium', () => apiFetch('/stats/premium'));

ipcMain.handle('total-servicos-cadastrados', () => apiFetch('/stats/servicos-cadastrados'));

ipcMain.handle('total-solicitacoes-aceitas', () => apiFetch('/stats/aceitas'));

ipcMain.handle('total-solicitacoes-pendentes', () => apiFetch('/stats/pendentes'));

ipcMain.handle('total-solicitacoes-recusadas', () => apiFetch('/stats/recusadas'));

ipcMain.handle('media-notas', () => apiFetch('/stats/media-notas'));

ipcMain.handle('alterar-usuario', (e, d) => apiFetch(`/usuarios/${d.cpf}`, 'PUT', d));

ipcMain.handle('buscar-ongs', () => apiFetch('/ongs'));

ipcMain.handle('alterar-ong', (e, d) => apiFetch(`/ongs/${encodeURIComponent(d.cnpj)}`, 'PUT', d));

ipcMain.handle('buscar-servicos', () => apiFetch('/servicos'));

ipcMain.handle('alterar-servico', (e, d) => apiFetch(`/adm/servicos/${encodeURIComponent(d.cod)}`, 'PUT', d));

ipcMain.handle('buscar-solicitacoes', () => apiFetch('/solicitacoes'));

ipcMain.handle('alterar-solicitacao', (e, d) => apiFetch(`/adm/solicitacoes/${encodeURIComponent(d.cod)}`, 'PUT', d));

ipcMain.handle('cadastrar-usuario', (e, usuario) => apiFetch('/usuarios', 'POST', usuario));

ipcMain.handle('cadastrar-ong', (e, ong) => apiFetch('/ongs', 'POST', ong));

ipcMain.handle('buscar-premium', () => apiFetch('/premium'));

ipcMain.handle('total-premium-geral', () => apiFetch('/stats/premium-total'));

ipcMain.handle('total-atrasadas', () => apiFetch('/stats/atrasadas'));

ipcMain.handle('total-receita', () => apiFetch('/stats/receita'));

// A API pega o login do admin pelo token; o login que vem da página é ignorado.
ipcMain.handle('alterar-login-adm', async (e, loginAntigo, novoLogin) => {
    const resposta = await apiFetch('/adm/login', 'PUT', { novoLogin });
    if (resposta.token) tokenAdm = resposta.token;
    return resposta;
});

ipcMain.handle('alterar-senha-adm', (e, login, senhaAtual, novaSenha) =>
    apiFetch('/adm/senha', 'PUT', { senhaAtual, novaSenha }));

ipcMain.handle('cadastrar-adm', (e, novoLogin, novaSenha) =>
    apiFetch('/adm/cadastrar', 'POST', { novoLogin, novaSenha }));

ipcMain.handle('buscar-servicos-revisao', () => apiFetch('/moderacao/servicos'));

ipcMain.handle('moderar-servico', (e, tipo, id, acao, admLogin) =>
    apiFetch(`/moderacao/servicos/${encodeURIComponent(tipo)}/${encodeURIComponent(id)}`, 'PUT', { acao }));

ipcMain.handle('buscar-contas-premium', () => apiFetch('/premium/contas'));

ipcMain.handle('remover-premium-usuario', (e, cpf) =>
  apiFetch(`/adm/usuarios/${encodeURIComponent(cpf)}/premium`, 'PUT'));

ipcMain.handle('remover-premium-ong', (e, cnpj) =>
  apiFetch(`/adm/ongs/${encodeURIComponent(cnpj)}/premium`, 'PUT'));

// abertura de janelas
ipcMain.on('abrir-janela-inicio', () => {
  inicioWindow();
  if (win) {
    win.close();
  }
});

ipcMain.on('abrir-janela-login', () => {
  tokenAdm = null;
  createWindow();
  if (inicio) {
    inicio.close();
  }
})

app.whenReady().then(() => {
  createWindow()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})

