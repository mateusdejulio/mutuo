//import Swal from 'sweetalert2';

//abrir janela inicial ao clicar no botão de login e verificação de campos
/*document.getElementById('logar').addEventListener('click', () => {
    const loginValue = document.getElementById('login').value;
    const senhaValue = document.getElementById('senha').value;
    if (loginValue && senhaValue) {
        window.api.abrirNovaJanela();
    }
    else {
        Swal.fire({
            icon: 'warning',
            title: 'Ops...',
            text: 'Preencha o Login e a Senha para continuar!',
            confirmButtonText: 'Entendi',
            confirmButtonColor: '#3a5a40',
            heightAuto: false
        });
    }
});*/

// listar clientes ao clicar no botão
/*document.getElementById('btnBuscar').addEventListener('click', async () => {
  const clientes = await window.api.buscarUsuarios();

  console.log(clientes);

  const lista = document.getElementById('listaUsuarios');
  lista.innerHTML = '';

  clientes.forEach(c => {
    const li = document.createElement('li');
    li.textContent = `${c.id} - ${c.nome}`;
    lista.appendChild(li);
  });
});*/