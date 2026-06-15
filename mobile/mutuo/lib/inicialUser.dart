import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/ongs.dart';
import 'package:mutuo/servicos.dart';
import 'package:mutuo/quem_somos.dart';

// ─── MODEL ────────────────────────────────────────────────
class Vaga {
  final String titulo;
  final String descricao;
  final String local;
  final String tempo;
  final String imagem;
  final String categoria;
  final String autor;
  final double avaliacao;
  final int totalAvaliacoes;

  Vaga({
    required this.titulo,
    required this.descricao,
    required this.local,
    required this.tempo,
    required this.imagem,
    this.categoria = "Geral",
    this.autor = "Voluntário",
    this.avaliacao = 4.0,
    this.totalAvaliacoes = 0,
  });
}

// ─── DETALHE VAGA ─────────────────────────────────────────
class DetalheVaga extends StatelessWidget {
  final Vaga vaga;

  const DetalheVaga({super.key, required this.vaga});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(vaga.titulo),
        backgroundColor: const Color(0xFF3A5A40),
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: vaga.titulo,
            child: Image.asset(
              vaga.imagem,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vaga.titulo,
                  style: GoogleFonts.quicksand(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "${vaga.local} • ${vaga.tempo}",
                  style: GoogleFonts.quicksand(fontSize: 14),
                ),
                const SizedBox(height: 20),
                Text(
                  vaga.descricao,
                  style: GoogleFonts.quicksand(fontSize: 14),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF588157),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Inscrição realizada!")),
                      );
                    },
                    child: Text(
                      "Participar",
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DATA CLASS AUXILIAR ──────────────────────────────────
class _StatData {
  final IconData icone;
  final Color iconeBg;
  final Color iconeColor;
  final String titulo;
  final String valor;
  final String? sub;
  final bool subPositivo;
  final bool subLink;

  _StatData({
    required this.icone,
    required this.iconeBg,
    required this.iconeColor,
    required this.titulo,
    required this.valor,
    this.sub,
    this.subPositivo = false,
    this.subLink = false,
  });
}

// ─── ACESSO RÁPIDO DATA ───────────────────────────────────
class _AcessoData {
  final IconData icone;
  final String label;
  final int? badge;
  final VoidCallback? onTap;

  _AcessoData({
    required this.icone,
    required this.label,
    this.badge,
    this.onTap,
  });
}

// ─── TELA PRINCIPAL ───────────────────────────────────────
class InicialUsuario extends StatefulWidget {
  final String nome;

  const InicialUsuario({super.key, required this.nome});

  @override
  State<InicialUsuario> createState() => _InicialUsuarioState();
}

class _InicialUsuarioState extends State<InicialUsuario> {
  int _fraseIndex = 0;
  int _bottomNavIndex = 0;

  // ── helper seguro para inicial do nome ──
  String get _inicial =>
      widget.nome.isNotEmpty ? widget.nome[0].toUpperCase() : "U";

  final List<String> _frases = [
    "Juntos, podemos construir um futuro mais humano.",
    "Pequenos gestos transformam grandes realidades.",
    "Voluntariar é dar o melhor de si ao próximo.",
  ];

  final List<Vaga> vagas = [
    Vaga(
      titulo: "Aulas de culinária",
      descricao:
          "Aprenda e ensine pratos deliciosos. Aulas práticas e divertidas para todos os níveis.",
      local: "São Paulo, SP",
      tempo: "1h 30min",
      imagem: "assets/images/imagemcomida.png",
      categoria: "Culinária",
      autor: "Mariana Lopes",
      avaliacao: 3.0,
      totalAvaliacoes: 1024,
    ),
    Vaga(
      titulo: "Passeio com cachorro",
      descricao:
          "Ajude a passear com cães resgatados e faça a diferença na vida deles.",
      local: "Campinas, SP",
      tempo: "1h",
      imagem: "assets/images/imagemcachorro.png",
      categoria: "Animais",
      autor: "João Silva",
      avaliacao: 4.5,
      totalAvaliacoes: 312,
    ),
    Vaga(
      titulo: "Apoio em evento",
      descricao: "Auxilie na organização de eventos sociais e conecte pessoas.",
      local: "Valinhos, SP",
      tempo: "3h",
      imagem: "assets/images/evento.png",
      categoria: "Eventos",
      autor: "Ana Costa",
      avaliacao: 4.0,
      totalAvaliacoes: 87,
    ),
  ];

  // ─── Paleta ───────────────────────────────────────────────
  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  // ─── NAVEGAR PARA SERVIÇOS ────────────────────────────────
  void _irParaServicos() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) =>
            Servicos(nome: widget.nome, initialNavIndex: 1),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) => setState(() => _bottomNavIndex = 0));
  }

  void _irParaOngs() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) =>
            Ongs(nome: widget.nome, initialNavIndex: 2),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) => setState(() => _bottomNavIndex = 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cardBoasVindas(),
                    const SizedBox(height: 24),
                    _sectionTitle("Resumo"),
                    const SizedBox(height: 12),
                    _gridEstatisticas(),
                    const SizedBox(height: 24),
                    _sectionTitle("Inspiração"),
                    const SizedBox(height: 12),
                    _cardFrase(),
                    const SizedBox(height: 28),
                    _sectionTitle("Acesso rápido"),
                    const SizedBox(height: 14),
                    _gridAcessoRapido(),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionTitle("Vagas em destaque"),
                    GestureDetector(
                      onTap: _irParaServicos,
                      child: Text(
                        "Ver todas →",
                        style: GoogleFonts.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _verdeMedio,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _carrosselVagas(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BOTTOM NAVIGATION BAR ────────────────────────────────
  Widget _buildBottomNav() {
    final List<_NavItem> navItems = [
      _NavItem(
        icon: Icons.home_rounded,
        outlinedIcon: Icons.home_outlined,
        label: "Início",
      ),
      _NavItem(
        icon: Icons.work_rounded,
        outlinedIcon: Icons.work_outline_rounded,
        label: "Serviços",
      ),
      _NavItem(
        icon: Icons.favorite_rounded,
        outlinedIcon: Icons.favorite_border_rounded,
        label: "ONGs",
      ),
      _NavItem(
        icon: Icons.chat_bubble_rounded,
        outlinedIcon: Icons.chat_bubble_outline_rounded,
        label: "Chat",
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _branco,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomNavigationBar(
          currentIndex: _bottomNavIndex,
          onTap: (index) {
            if (index == 1) {
              _irParaServicos();
            } else if (index == 2) {
              _irParaOngs();
            } else {
              setState(() => _bottomNavIndex = index);
            }
          },
          backgroundColor: _branco,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedItemColor: _verde,
          unselectedItemColor: const Color(0xFFADB5BD),
          selectedLabelStyle: GoogleFonts.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          items: List.generate(navItems.length, (i) {
            final item = navItems[i];
            final isSelected = _bottomNavIndex == i;
            return BottomNavigationBarItem(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _verde.withOpacity(0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? item.icon : item.outlinedIcon,
                  size: 22,
                ),
              ),
              label: item.label,
            );
          }),
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────
  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _verde,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      child: Row(
        children: [
          Text(
            "Mútuo",
            style: GoogleFonts.quicksand(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _branco,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _verdeMedio.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: _branco,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const Login()),
                );
              } else if (value == 'quem_somos') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuemSomos(nome: widget.nome),
                  ),
                );
              }
            },
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'quem_somos',
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: _verde),
                    const SizedBox(width: 8),
                    Text(
                      "Quem somos",
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 18, color: _verde),
                    const SizedBox(width: 8),
                    Text(
                      "Sair",
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 20,
              backgroundColor: _bege,
              child: Text(
                _inicial,
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _verde,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CARD BOAS-VINDAS ─────────────────────────────────────
  Widget _cardBoasVindas() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bege,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _verde.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.wb_sunny_rounded, color: _verde, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bem-vindo(a), ${widget.nome.isNotEmpty ? widget.nome : 'Usuário'}!",
                  style: GoogleFonts.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _verde,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Confira as novidades do seu painel hoje",
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    color: const Color(0xFF6B705C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: _verdeMedio,
          ),
        ],
      ),
    );
  }

  // ─── TÍTULO DE SEÇÃO ──────────────────────────────────────
  Widget _sectionTitle(String texto) {
    return Text(
      texto,
      style: GoogleFonts.quicksand(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF344E41),
      ),
    );
  }

  // ─── GRID ESTATÍSTICAS ────────────────────────────────────
  Widget _gridEstatisticas() {
    final stats = [
      _StatData(
        icone: Icons.access_time_rounded,
        iconeBg: const Color(0xFFD8F3DC),
        iconeColor: const Color(0xFF2D6A4F),
        titulo: "Horas de serviço",
        valor: "24h",
        sub: "+8h este mês",
        subPositivo: true,
      ),
      _StatData(
        icone: Icons.check_circle_rounded,
        iconeBg: const Color(0xFFD0E8FF),
        iconeColor: const Color(0xFF1A73E8),
        titulo: "Trabalhos concluídos",
        valor: "5",
      ),
      _StatData(
        icone: Icons.star_rounded,
        iconeBg: const Color(0xFFFFF3B0),
        iconeColor: const Color(0xFFF4A261),
        titulo: "Pontos",
        valor: "+150",
        sub: "+50 este mês",
        subPositivo: true,
      ),
      _StatData(
        icone: Icons.workspace_premium_rounded,
        iconeBg: const Color(0xFFEDE7F6),
        iconeColor: const Color(0xFF7B52AB),
        titulo: "Plano atual",
        valor: "Gratuito",
        sub: "melhore seu plano",
        subLink: true,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: stats.map((s) => _statCard(s)).toList(),
    );
  }

  Widget _statCard(_StatData s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E4DE), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: s.iconeBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(s.icone, color: s.iconeColor, size: 22),
          ),
          Text(
            s.valor,
            style: GoogleFonts.quicksand(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2D3319),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B705C),
                ),
              ),
              if (s.sub != null)
                Text(
                  s.sub!,
                  style: GoogleFonts.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: s.subLink
                        ? _verdeMedio
                        : s.subPositivo
                        ? const Color(0xFF52B788)
                        : const Color(0xFF9E9E9E),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── CARD FRASE ───────────────────────────────────────────
  Widget _cardFrase() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
      decoration: BoxDecoration(
        color: _bege,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "\u201C",
            style: GoogleFonts.quicksand(
              fontSize: 60,
              height: 0.6,
              color: _verdeMedio.withOpacity(0.35),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _frases[_fraseIndex],
              key: ValueKey(_fraseIndex),
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF344E41),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _frases.length,
              (i) => GestureDetector(
                onTap: () => setState(() => _fraseIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _fraseIndex == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _fraseIndex == i
                        ? _verdeMedio
                        : _verde.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ACESSO RÁPIDO ────────────────────────────────────────
  Widget _gridAcessoRapido() {
    final itens = [
      _AcessoData(
        icone: Icons.search_rounded,
        label: "Buscar Vagas",
        onTap: _irParaServicos,
      ),
      _AcessoData(
        icone: Icons.favorite_border_rounded,
        label: "ONGs",
        onTap: _irParaOngs,
      ),
      _AcessoData(icone: Icons.chat_bubble_outline_rounded, label: "Chat"),
      _AcessoData(
        icone: Icons.workspace_premium_outlined,
        label: "Certificados",
      ),
      _AcessoData(
        icone: Icons.notifications_none_rounded,
        label: "Notificações",
        badge: 3,
      ),
      _AcessoData(icone: Icons.trending_up_rounded, label: "Meu Plano"),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      children: itens.map((item) => _acessoCard(item)).toList(),
    );
  }

  Widget _acessoCard(_AcessoData item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _branco,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE0DDD8), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2EE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icone, color: _verde, size: 22),
                ),
                if (item.badge != null)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE63946),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${item.badge}",
                        style: GoogleFonts.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _branco,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF344E41),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CARROSSEL DE VAGAS ───────────────────────────────────
  Widget _carrosselVagas() {
    return SizedBox(
      height: 310,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: vagas.length,
        itemBuilder: (context, index) {
          final vaga = vagas[index];
          return _vagaCard(vaga);
        },
      ),
    );
  }

  Widget _vagaCard(Vaga vaga) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetalheVaga(vaga: vaga)),
      ),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: _branco,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: Stack(
                children: [
                  Hero(
                    tag: vaga.titulo,
                    child: Image.asset(
                      vaga.imagem,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 140,
                        color: const Color(0xFFB7D5B0),
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _verde,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        vaga.categoria.toUpperCase(),
                        style: GoogleFonts.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _branco,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vaga.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.quicksand(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2D3319),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vaga.descricao,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.quicksand(
                            fontSize: 11,
                            color: const Color(0xFF6B705C),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: _bege,
                          child: Text(
                            vaga.autor.isNotEmpty
                                ? vaga.autor[0].toUpperCase()
                                : "V",
                            style: GoogleFonts.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _verde,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vaga.autor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.quicksand(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF344E41),
                                ),
                              ),
                              Row(
                                children: [
                                  ...List.generate(5, (i) {
                                    if (i < vaga.avaliacao.floor()) {
                                      return const Icon(
                                        Icons.star_rounded,
                                        size: 12,
                                        color: Color(0xFFF4A261),
                                      );
                                    } else if (i < vaga.avaliacao) {
                                      return const Icon(
                                        Icons.star_half_rounded,
                                        size: 12,
                                        color: Color(0xFFF4A261),
                                      );
                                    } else {
                                      return const Icon(
                                        Icons.star_border_rounded,
                                        size: 12,
                                        color: Color(0xFFCCCCCC),
                                      );
                                    }
                                  }),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${vaga.avaliacao.toStringAsFixed(1)} (${vaga.totalAvaliacoes})",
                                    style: GoogleFonts.quicksand(
                                      fontSize: 10,
                                      color: const Color(0xFF6B705C),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: _verdeMedio,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            vaga.local,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.quicksand(
                              fontSize: 11,
                              color: const Color(0xFF6B705C),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: _verdeMedio,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          vaga.tempo,
                          style: GoogleFonts.quicksand(
                            fontSize: 11,
                            color: const Color(0xFF6B705C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── NAV ITEM AUXILIAR ────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;

  _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
  });
}
