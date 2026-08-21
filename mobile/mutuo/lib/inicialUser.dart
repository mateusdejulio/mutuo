import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/ongs.dart';
import 'package:mutuo/servicos.dart';
import 'package:mutuo/quem_somos.dart';
import 'package:mutuo/perfil.dart';
import 'package:mutuo/widgets/avatar_perfil.dart';
import 'package:mutuo/services/api_service.dart';

// ─── MODEL ────────────────────────────────────────────────
// Agora representa um serviço vindo do banco (rota /servicos-destaque)
// ─── MODEL ────────────────────────────────────────────────
class Vaga {
  final String? id;
  final String titulo;
  final String descricao;
  final String local;
  final String tempo;
  final String imagem;
  final String? imagemUrl;
  final String categoria;
  final String autor;
  final double avaliacao;
  final int totalAvaliacoes;
  final int pontos;

  Vaga({
    this.id,
    required this.titulo,
    required this.descricao,
    required this.local,
    required this.tempo,
    required this.imagem,
    this.imagemUrl,
    this.categoria = "Geral",
    this.autor = "Voluntário",
    this.avaliacao = 4.0,
    this.totalAvaliacoes = 0,
    this.pontos = 0,
  });

  factory Vaga.fromJson(Map<String, dynamic> json) {
    final horas = json['qtdHoras'];
    final caminhoImagem = json['imagem']?.toString();
    return Vaga(
      id: json['cod']?.toString(),
      titulo: json['nome']?.toString() ?? '',
      descricao: json['descricao']?.toString() ?? '',
      local: [json['cidade'], json['estado']]
          .where((v) => v != null && v.toString().isNotEmpty)
          .join(', '),
      tempo: horas != null ? '${horas}h' : '',
      imagem: caminhoImagem ?? '',
      imagemUrl: (caminhoImagem != null && caminhoImagem.isNotEmpty)
          ? '${ApiService.baseUrl}$caminhoImagem'
          : null,
      categoria: (json['foco']?.toString().isNotEmpty ?? false)
          ? json['foco'].toString()
          : 'Geral',
      autor: (json['nomeUsuario']?.toString().isNotEmpty ?? false)
          ? json['nomeUsuario'].toString()
          : 'Voluntário',
      pontos: int.tryParse('${json['pontos'] ?? 0}') ?? 0,
    );
  }
}

// ─── DETALHE VAGA ─────────────────────────────────────────
class DetalheVaga extends StatelessWidget {
  final Vaga vaga;

  const DetalheVaga({super.key, required this.vaga});

  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                                Hero(
                  tag: 'vaga_${vaga.id}',
                  child: vaga.imagemUrl != null
                      ? Image.network(
                          vaga.imagemUrl!,
                          height: 280,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 280,
                              width: double.infinity,
                              color: const Color(0xFFB7D5B0),
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 50,
                              ),
                            );
                          },
                        )
                      : Container(
                          height: 280,
                          width: double.infinity,
                          color: const Color(0xFFB7D5B0),
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFF344E41),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _verde,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      vaga.categoria.toUpperCase(),
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF4A261)),
                        const SizedBox(width: 4),
                        Text(
                          "${vaga.pontos} pts",
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF344E41),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                decoration: const BoxDecoration(
                  color: _branco,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vaga.titulo,
                      style: GoogleFonts.quicksand(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2D3319),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _verde.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: _verde.withOpacity(0.3), width: 1.5),
                          ),
                          child: const Icon(Icons.person_rounded, color: _verde, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          vaga.autor,
                          style: GoogleFonts.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF344E41),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: _verdeMedio),
                        const SizedBox(width: 4),
                        Text(
                          vaga.local,
                          style: GoogleFonts.quicksand(fontSize: 13, color: const Color(0xFF6B705C)),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time_rounded, size: 16, color: _verdeMedio),
                        const SizedBox(width: 4),
                        Text(
                          vaga.tempo,
                          style: GoogleFonts.quicksand(fontSize: 13, color: const Color(0xFF6B705C)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(height: 1, color: const Color(0xFFEDEAE5)),
                    const SizedBox(height: 22),
                    Text(
                      "Sobre a vaga",
                      style: GoogleFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF344E41),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      vaga.descricao,
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        height: 1.6,
                        color: const Color(0xFF6B705C),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _verde,
                              side: BorderSide(color: _verde.withOpacity(0.4), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Em breve: chat de dúvidas!")),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                            label: Text(
                              "Tirar dúvidas",
                              style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _verde,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Inscrição realizada!")),
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: Text(
                              "Participar",
                              style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
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
  final String cpf;

  const InicialUsuario({super.key, required this.nome, required this.cpf});

  @override
  State<InicialUsuario> createState() => _InicialUsuarioState();
}

class _InicialUsuarioState extends State<InicialUsuario> {
  int _fraseIndex = 0;
  int _bottomNavIndex = 0;

  final ApiService _apiService = ApiService();
  int _horasServico = 0;
  int _trabalhosConcluidos = 0;
  int _pontos = 0;
  String _plano = "Gratuito";
  bool _carregandoStats = true;

  // ─── NOVO: serviços em destaque vindos do banco ───
  List<Vaga> _vagas = [];
  bool _carregandoVagas = true;

  @override
  void initState() {
    super.initState();
    _carregarEstatisticas();
    _carregarVagasDestaque();
  }

  Future<void> _carregarEstatisticas() async {
    final dashboard = await _apiService.buscarDashboardUsuario(widget.cpf);
    if (!mounted) return;

    if (dashboard != null && dashboard['error'] == null) {
      setState(() {
        _horasServico =
            int.tryParse('${dashboard['horasServico'] ?? 0}') ?? 0;
        _trabalhosConcluidos =
            int.tryParse('${dashboard['trabalhosConcluidos'] ?? 0}') ?? 0;
        _pontos = int.tryParse('${dashboard['pontos'] ?? 0}') ?? 0;
        _plano = dashboard['plano']?.toString() ?? "Gratuito";
        _carregandoStats = false;
      });
    } else {
      setState(() => _carregandoStats = false);
    }
  }

  // ─── NOVO: busca os serviços em destaque na API e monta a lista de Vaga ───
  Future<void> _carregarVagasDestaque() async {
    final dados = await _apiService.buscarServicosDestaque();
    if (!mounted) return;

    setState(() {
      _vagas = dados
          .whereType<Map<String, dynamic>>()
          .map((json) => Vaga.fromJson(json))
          .toList();
      _carregandoVagas = false;
    });
  }

  // ── helper seguro para inicial do nome ──
  String get _inicial =>
      widget.nome.isNotEmpty ? widget.nome[0].toUpperCase() : "U";

  final List<String> _frases = [
    "Juntos, podemos construir um futuro mais humano.",
    "Pequenos gestos transformam grandes realidades.",
    "Voluntariar é dar o melhor de si ao próximo.",
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
            Servicos(nome: widget.nome, cpf: widget.cpf, initialNavIndex: 1),
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
            Ongs(nome: widget.nome, cpf: widget.cpf, initialNavIndex: 2),
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
              } else if (value == 'meu_perfil') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PerfilUsuario(
                      cpf: widget.cpf,
                      nomeInicial: widget.nome,
                    ),
                  ),
                );
              } else if (value == 'quem_somos') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuemSomos(nome: widget.nome, cpf: widget.cpf),
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
                value: 'meu_perfil',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18, color: _verde),
                    const SizedBox(width: 8),
                    Text(
                      "Meu Perfil",
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
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
            child: AvatarPerfil(cpf: widget.cpf, nome: widget.nome, radius: 20),
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
        valor: _carregandoStats ? "…" : "${_horasServico}h",
      ),
      _StatData(
        icone: Icons.check_circle_rounded,
        iconeBg: const Color(0xFFD0E8FF),
        iconeColor: const Color(0xFF1A73E8),
        titulo: "Trabalhos concluídos",
        valor: _carregandoStats ? "…" : "$_trabalhosConcluidos",
      ),
      _StatData(
        icone: Icons.star_rounded,
        iconeBg: const Color(0xFFFFF3B0),
        iconeColor: const Color(0xFFF4A261),
        titulo: "Pontos",
        valor: _carregandoStats ? "…" : "+$_pontos",
      ),
      _StatData(
        icone: Icons.workspace_premium_rounded,
        iconeBg: const Color(0xFFEDE7F6),
        iconeColor: const Color(0xFF7B52AB),
        titulo: "Plano atual",
        valor: _carregandoStats ? "…" : _plano,
        sub: !_carregandoStats && _plano == "Gratuito"
            ? "melhore seu plano"
            : null,
        subLink: !_carregandoStats && _plano == "Gratuito",
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

  // ─── CARROSSEL DE VAGAS (agora vindo do banco) ─────────────
  Widget _carrosselVagas() {
    if (_carregandoVagas) {
      return const SizedBox(
        height: 310,
        child: Center(child: CircularProgressIndicator(color: _verde)),
      );
    }

    if (_vagas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _branco,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE0DDD8)),
          ),
          child: Column(
            children: [
              const Icon(Icons.work_off_outlined, color: _verdeMedio, size: 32),
              const SizedBox(height: 8),
              Text(
                "Nenhuma vaga em destaque no momento",
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B705C),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 310,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _vagas.length,
        itemBuilder: (context, index) {
          final vaga = _vagas[index];
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
                  tag: 'vaga_${vaga.id}',
                  child: vaga.imagemUrl != null
                      ? Image.network(
                          vaga.imagemUrl!,
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
                        )
                      : Container(
                          height: 140,
                          color: const Color(0xFFB7D5B0),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white54,
                            size: 40,
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