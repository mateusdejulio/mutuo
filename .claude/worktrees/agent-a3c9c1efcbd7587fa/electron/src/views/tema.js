(function aplicarTemaImediato() {
    const temaSalvo = localStorage.getItem('tema');
    if (temaSalvo === 'dark') {
        document.documentElement.classList.add('dark');
        document.documentElement.classList.remove('light');
    } else {
        document.documentElement.classList.add('light');
        document.documentElement.classList.remove('dark');
    }
})();


window.addEventListener('DOMContentLoaded', () => {
    const temaSalvo = localStorage.getItem('tema');
    const pag = document.getElementById("pagina");
    const img = document.getElementById("img-tema");

    if (temaSalvo === 'dark') {
        pag.classList.replace('light', 'dark');
        if (img) img.src = '../public/img/claro.png';
    } else {
        pag.classList.replace('dark', 'light');
        if (img) img.src = '../public/img/escuro.png';
    }

    document.getElementById('tema').addEventListener('click', function(e) {
        e.preventDefault();
        changeMode();
    });
});

function changeMode() {
    const pag = document.getElementById("pagina");
    const img = document.getElementById("img-tema");

    pag.classList.toggle('dark');
    pag.classList.toggle('light');

    const temaAtual = pag.classList.contains('dark') ? 'dark' : 'light';
    localStorage.setItem('tema', temaAtual);

    document.documentElement.className = temaAtual;

    if (img) {
        img.src = temaAtual === 'dark' 
            ? '../public/img/claro.png' 
            : '../public/img/escuro.png';
    }

    if (typeof atualizarTemaGrafico === 'function') {
    atualizarTemaGrafico();
}
}