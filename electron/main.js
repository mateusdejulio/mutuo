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
const API_URL = 'http://localhost:3000';

//variáveis
let win;
let inicio;

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
    if (body) options.body = JSON.stringify(body);
    const response = await fetch(`${API_URL}${endpoint}`, options);
    return await response.json();
}

ipcMain.handle('validar-login', (e, login, senha) => apiFetch('/login', 'POST', { login, senha }));

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

ipcMain.handle('alterar-servico', (e, d) => apiFetch(`/servicos/${encodeURIComponent(d.cod)}`, 'PUT', d));

ipcMain.handle('buscar-solicitacoes', () => apiFetch('/solicitacoes'));

ipcMain.handle('alterar-solicitacao', (e, d) => apiFetch(`/solicitacoes/${d.cod}`, 'PUT', d));

ipcMain.handle('cadastrar-usuario', (e, usuario) => apiFetch('/usuarios', 'POST', usuario));

ipcMain.handle('cadastrar-ong', (e, ong) => apiFetch('/ongs', 'POST', ong));

ipcMain.handle('buscar-premium', () => apiFetch('/premium'));

ipcMain.handle('total-premium-geral', () => apiFetch('/stats/premium-total'));

ipcMain.handle('total-atrasadas', () => apiFetch('/stats/atrasadas'));

ipcMain.handle('total-receita', () => apiFetch('/stats/receita'));

ipcMain.handle('alterar-login-adm', (e, loginAntigo, novoLogin) =>
    apiFetch('/adm/login', 'PUT', { loginAntigo, novoLogin }));

ipcMain.handle('alterar-senha-adm', (e, login, senhaAtual, novaSenha) =>
    apiFetch('/adm/senha', 'PUT', { login, senhaAtual, novaSenha }));

ipcMain.handle('cadastrar-adm', (e, novoLogin, novaSenha) =>
    apiFetch('/adm/cadastrar', 'POST', { novoLogin, novaSenha }));

// abertura de janelas
ipcMain.on('abrir-janela-inicio', () => {
  inicioWindow();
  if (win) {
    win.close();
  }
});

ipcMain.on('abrir-janela-login', () => {
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

