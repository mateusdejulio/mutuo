import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/ongs.dart';

// ─── MODEL ────────────────────────────────────────────────
class Servico {
  final String titulo;
  final String descricao;
  final String local;
  final String tempo;
  final String imagem;
  final String categoria;
  final String autor;
  final double avaliacao;
  final int totalAvaliacoes;

  Servico({
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

// ─── DETALHE SERVIÇO ──────────────────────────────────────
class DetalheServico extends StatelessWidget {
  final Servico servico;

  const DetalheServico({super.key, required this.servico});

  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          servico.titulo,
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _verde,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'servico_${servico.titulo}',
              child: Container(
                height: 220,
                width: double.infinity,
                color: const Color(0xFFB7D5B0),
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _verde,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      servico.categoria.toUpperCase(),
                      style: GoogleFonts.quicksand(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    servico.titulo,
                    style: GoogleFonts.quicksand(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3319),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: _verdeMedio),
                      const SizedBox(width: 4),
                      Text(servico.local, style: GoogleFonts.quicksand(fontSize: 13, color: const Color(0xFF6B705C))),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time_rounded, size: 14, color: _verdeMedio),
                      const SizedBox(width: 4),
                      Text(servico.tempo, style: GoogleFonts.quicksand(fontSize: 13, color: const Color(0xFF6B705C))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    servico.descricao,
                    style: GoogleFonts.quicksand(fontSize: 14, height: 1.6, color: const Color(0xFF344E41)),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _verde,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.info_outline, size: 18),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Interesse registrado!")),
                        );
                      },
                      label: Text(
                        "Saiba mais",
                        style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TELA SERVIÇOS ────────────────────────────────────────
class Servicos extends StatefulWidget {
  final String nome;
  final int initialNavIndex;

  const Servicos({
    super.key,
    required this.nome,
    this.initialNavIndex = 1,
  });

  @override
  State<Servicos> createState() => _ServicosState();
}

class _ServicosState extends State<Servicos> {
  late int _bottomNavIndex;
  String _categoriaSelecionada = "Todos";
  final TextEditingController _buscaController = TextEditingController();
  String _busca = "";

  // ─── Paleta ───────────────────────────────────────────────
  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  final List<String> _categorias = [
    "Todos",
    "Jardinagem",
    "Culinária",
    "Manutenção",
    "Educação",
    "Tecnologia",
    "Beleza",
    "Bem-estar",
    "Música",
  ];

  final List<Servico> _todosServicos = [
    Servico(
      titulo: "Aula de culinária",
      descricao: "Aprenda a fazer pratos deliciosos e saudáveis. Aulas práticas e divertidas para todos os níveis.",
      local: "Rio de Janeiro, RJ",
      tempo: "1h 30min",
      imagem: "assets/images/imagemcomida.jpg",
      categoria: "Culinária",
      autor: "Mariana Lopes",
      avaliacao: 5.0,
      totalAvaliacoes: 1024,
    ),
    Servico(
      titulo: "Jardinagem urbana",
      descricao: "Transforme seu espaço com plantas e hortas. Aprenda técnicas simples de cultivo.",
      local: "São Paulo, SP",
      tempo: "2h",
      imagem: "assets/images/imagemjardineiro.jpg",
      categoria: "Jardinagem",
      autor: "Carlos Mendes",
      avaliacao: 4.5,
      totalAvaliacoes: 312,
    ),
    Servico(
      titulo: "Aula de violão",
      descricao: "Do básico ao intermediário. Aprenda músicas populares e técnicas de cordas.",
      local: "Belo Horizonte, MG",
      tempo: "1h",
      imagem: "assets/images/violao.png",
      categoria: "Música",
      autor: "Ana Costa",
      avaliacao: 4.8,
      totalAvaliacoes: 87,
    ),
    Servico(
      titulo: "Manutenção elétrica",
      descricao: "Pequenos reparos elétricos residenciais. Troca de tomadas, interruptores e lâmpadas.",
      local: "Campinas, SP",
      tempo: "1h 30min",
      imagem: "assets/images/manutencao.png",
      categoria: "Manutenção",
      autor: "Roberto Alves",
      avaliacao: 4.2,
      totalAvaliacoes: 56,
    ),
    Servico(
      titulo: "Reforço escolar",
      descricao: "Aulas de matemática e português para ensino fundamental. Atendimento personalizado.",
      local: "Online",
      tempo: "2h",
      imagem: "assets/images/professor.jpg",
      categoria: "Educação",
      autor: "Juliana Santos",
      avaliacao: 5.0,
      totalAvaliacoes: 203,
    ),
    Servico(
      titulo: "Bem-estar e meditação",
      descricao: "Sessões guiadas de meditação e técnicas de relaxamento para o dia a dia.",
      local: "Online",
      tempo: "45min",
      imagem: "assets/images/yoga.png",
      categoria: "Bem-estar",
      autor: "Fernanda Lima",
      avaliacao: 4.9,
      totalAvaliacoes: 430,
    ),
    Servico(
      titulo: "Corte e estilo",
      descricao: "Corte de cabelo e orientação de estilo pessoal em domicílio.",
      local: "São Paulo, SP",
      tempo: "1h",
      imagem: "assets/images/cabelo.jpg",
      categoria: "Beleza",
      autor: "Patricia Rocha",
      avaliacao: 4.7,
      totalAvaliacoes: 158,
    ),
  ];

  List<Servico> get _servicosFiltrados {
    return _todosServicos.where((s) {
      final categoriaOk = _categoriaSelecionada == "Todos" || s.categoria == _categoriaSelecionada;
      final buscaOk = _busca.isEmpty ||
          s.titulo.toLowerCase().contains(_busca.toLowerCase()) ||
          s.descricao.toLowerCase().contains(_busca.toLowerCase());
      return categoriaOk && buscaOk;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _bottomNavIndex = widget.initialNavIndex;
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  // ─── NAVEGAÇÃO BOTTOM NAV ─────────────────────────────────
  void _onNavTap(int index) {
  if (index == _bottomNavIndex) return;
  if (index == 0) {
    Navigator.pop(context);
  } else if (index == 2) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => Ongs(nome: widget.nome, initialNavIndex: 2),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  } else {
    setState(() => _bottomNavIndex = index);
  }
}

  @override
  Widget build(BuildContext context) {
    final filtrados = _servicosFiltrados;

    return Scaffold(
      backgroundColor: _fundo,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            // ─── HEADER ───────────────────────────────────────
            _header(context),

            // ─── CONTEÚDO SCROLLÁVEL ──────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── HERO BUSCA ───────────────────────────
                    _heroBusca(),

                    const SizedBox(height: 20),

                    // ─── FILTROS + ORDENAR ────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            "${filtrados.length} serviços encontrados",
                            style: GoogleFonts.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B705C),
                            ),
                          ),
                          const Spacer(),
                          _chipAcao(
                            icone: Icons.tune_rounded,
                            label: "Filtros",
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _chipAcao(
                            icone: Icons.swap_vert_rounded,
                            label: "Ordenar",
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ─── CHIPS CATEGORIAS ─────────────────────
                    _chipsCategorias(),

                    const SizedBox(height: 20),

                    // ─── LISTA DE SERVIÇOS ────────────────────
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filtrados.length,
                      itemBuilder: (context, index) => _servicoCard(filtrados[index]),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HEADER (igual ao InicialUsuario) ─────────────────────
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
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => Login()),
                  (route) => false,
                );
              }
            },
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 18, color: _verde),
                    const SizedBox(width: 8),
                    Text("Sair", style: GoogleFonts.quicksand(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 20,
              backgroundColor: _bege,
              child: Text(
                widget.nome.isNotEmpty ? widget.nome[0].toUpperCase() : "U",
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

  // ─── HERO BUSCA ───────────────────────────────────────────
  Widget _heroBusca() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: _verde,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Encontre Serviços na\nSua Comunidade",
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _branco,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Troque serviços com pessoas próximas e faça parte de uma economia colaborativa.",
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: _branco.withOpacity(0.80),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: _branco,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(Icons.search_rounded, color: _verde.withOpacity(0.5), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _buscaController,
                    onChanged: (v) => setState(() => _busca = v),
                    style: GoogleFonts.quicksand(fontSize: 14, color: const Color(0xFF344E41)),
                    decoration: InputDecoration(
                      hintText: "Buscar serviços...",
                      hintStyle: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: const Color(0xFF9E9E9E),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _busca = _buscaController.text),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _verdeMedio,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      "Buscar",
                      style: GoogleFonts.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _branco,
                      ),
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

  // ─── CHIP AÇÃO (Filtros / Ordenar) ────────────────────────
  Widget _chipAcao({required IconData icone, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _branco,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDD9D3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icone, size: 15, color: _verde),
            const SizedBox(width: 5),
            Text(
              label,
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

  // ─── CHIPS CATEGORIAS ─────────────────────────────────────
  Widget _chipsCategorias() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categorias.length,
        itemBuilder: (context, index) {
          final cat = _categorias[index];
          final selecionado = cat == _categoriaSelecionada;
          return GestureDetector(
            onTap: () => setState(() => _categoriaSelecionada = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selecionado ? _verde : _branco,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selecionado ? _verde : const Color(0xFFDDD9D3),
                  width: 1,
                ),
                boxShadow: selecionado
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Text(
                cat,
                style: GoogleFonts.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selecionado ? _branco : const Color(0xFF344E41),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── CARD SERVIÇO ─────────────────────────────────────────
  Widget _servicoCard(Servico servico) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetalheServico(servico: servico)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: _branco,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── IMAGEM ───────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: Stack(
                children: [
                  Hero(
                    tag: 'servico_${servico.titulo}',
                    child: Container(
                      height: 170,
                      width: double.infinity,
                      color: const Color(0xFFB7D5B0),
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                  // Tag categoria
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _verde,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        servico.categoria.toUpperCase(),
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

            // ─── CONTEÚDO ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    servico.titulo,
                    style: GoogleFonts.quicksand(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2D3319),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Descrição
                  Text(
                    servico.descricao,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      color: const Color(0xFF6B705C),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Autor + avaliação
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: _bege,
                        child: Text(
                          servico.autor.isNotEmpty ? servico.autor[0].toUpperCase() : "V",
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _verde,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            servico.autor,
                            style: GoogleFonts.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF344E41),
                            ),
                          ),
                          Row(
                            children: [
                              ...List.generate(5, (i) {
                                if (i < servico.avaliacao.floor()) {
                                  return const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF4A261));
                                } else if (i < servico.avaliacao) {
                                  return const Icon(Icons.star_half_rounded, size: 13, color: Color(0xFFF4A261));
                                } else {
                                  return const Icon(Icons.star_border_rounded, size: 13, color: Color(0xFFCCCCCC));
                                }
                              }),
                              const SizedBox(width: 4),
                              Text(
                                "${servico.avaliacao.toStringAsFixed(1)} (${servico.totalAvaliacoes})",
                                style: GoogleFonts.quicksand(fontSize: 11, color: const Color(0xFF6B705C)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Local + Tempo
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: _verdeMedio),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          servico.local,
                          style: GoogleFonts.quicksand(fontSize: 12, color: const Color(0xFF6B705C)),
                        ),
                      ),
                      const Icon(Icons.access_time_rounded, size: 13, color: _verdeMedio),
                      const SizedBox(width: 3),
                      Text(
                        servico.tempo,
                        style: GoogleFonts.quicksand(fontSize: 12, color: const Color(0xFF6B705C)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Botão
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _verde,
                        foregroundColor: _branco,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.info_outline, size: 16),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetalheServico(servico: servico)),
                      ),
                      label: Text(
                        "Saiba mais",
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BOTTOM NAVIGATION BAR (igual ao InicialUsuario) ──────
  Widget _buildBottomNav() {
    final List<_NavItem> navItems = [
      _NavItem(icon: Icons.home_rounded, outlinedIcon: Icons.home_outlined, label: "Início"),
      _NavItem(icon: Icons.work_rounded, outlinedIcon: Icons.work_outline_rounded, label: "Serviços"),
      _NavItem(icon: Icons.favorite_rounded, outlinedIcon: Icons.favorite_border_rounded, label: "ONGs"),
      _NavItem(icon: Icons.chat_bubble_rounded, outlinedIcon: Icons.chat_bubble_outline_rounded, label: "Chat"),
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
          onTap: _onNavTap,
          backgroundColor: _branco,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedItemColor: _verde,
          unselectedItemColor: const Color(0xFFADB5BD),
          selectedLabelStyle: GoogleFonts.quicksand(fontSize: 11, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.quicksand(fontSize: 11, fontWeight: FontWeight.w600),
          items: List.generate(navItems.length, (i) {
            final item = navItems[i];
            final isSelected = _bottomNavIndex == i;
            return BottomNavigationBarItem(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? _verde.withOpacity(0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isSelected ? item.icon : item.outlinedIcon, size: 22),
              ),
              label: item.label,
            );
          }),
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

  _NavItem({required this.icon, required this.outlinedIcon, required this.label});
}