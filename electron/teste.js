const { app, BrowserWindow } = require('electron');

console.log('INICIOU');

app.whenReady().then(() => {
  console.log('CRIANDO JANELA');

  const win = new BrowserWindow({
    width: 800,
    height: 600
  });

  win.loadURL('data:text/html,<h1>Electron OK</h1>');
});