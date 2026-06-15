import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/servicos.dart';
import 'package:mutuo/quem_somos.dart';

// ─── MODEL ────────────────────────────────────────────────
class Ong {
  final String titulo;
  final String descricao;
  final String local;
  final String tempo;
  final String categoria;
  final String nomeOng;
  final double avaliacao;
  final int totalAvaliacoes;
  final String imagem;

  Ong({
    required this.titulo,
    required this.descricao,
    required this.local,
    required this.tempo,
    required this.imagem,
    this.categoria = "Geral",
    this.nomeOng = "ONG",
    this.avaliacao = 4.0,
    this.totalAvaliacoes = 0,
  });
}

// ─── DETALHE ONG ──────────────────────────────────────────
class DetalheOng extends StatelessWidget {
  final Ong ong;

  const DetalheOng({super.key, required this.ong});

  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ong.titulo,
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
              tag: 'ong_${ong.titulo}',
              child: Image.asset(
                ong.imagem,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    height: 220,
                    width: double.infinity,
                    color: const Color(0xFFB7D5B0),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _verde,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ong.categoria.toUpperCase(),
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
                    ong.titulo,
                    style: GoogleFonts.quicksand(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3319),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: _verdeMedio,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ong.local,
                        style: GoogleFonts.quicksand(
                          fontSize: 13,
                          color: const Color(0xFF6B705C),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: _verdeMedio,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ong.tempo,
                        style: GoogleFonts.quicksand(
                          fontSize: 13,
                          color: const Color(0xFF6B705C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    ong.descricao,
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      height: 1.6,
                      color: const Color(0xFF344E41),
                    ),
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
                          const SnackBar(
                            content: Text("Interesse registrado!"),
                          ),
                        );
                      },
                      label: Text(
                        "Saiba mais",
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
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
}

// ─── TELA ONGs ────────────────────────────────────────────
class Ongs extends StatefulWidget {
  final String nome;
  final int initialNavIndex;

  const Ongs({super.key, required this.nome, this.initialNavIndex = 2});

  @override
  State<Ongs> createState() => _OngsState();
}

class _OngsState extends State<Ongs> {
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
    "Animais",
    "Crianças e adolescentes",
    "Idosos",
    "Ambientais",
    "Educação",
  ];

  final List<Ong> _todasOngs = [
    Ong(
      titulo: "Passeie com os cachorros",
      descricao: "...",
      local: "Rio de Janeiro, RJ",
      tempo: "30min",
      imagem: "assets/images/passeioCachorro.png",
      categoria: "Animais",
      nomeOng: "Instituto Cães Amigos",
    ),
    Ong(
      titulo: "Aulas de reforço para crianças",
      descricao:
          "Apoie crianças em situação de vulnerabilidade com aulas de reforço escolar. Faça a diferença na educação.",
      local: "São Paulo, SP",
      tempo: "2h",
      imagem: "assets/images/aulaOng.png",
      categoria: "Crianças e adolescentes",
      nomeOng: "ONG Crescer Juntos",
      avaliacao: 4.8,
      totalAvaliacoes: 312,
    ),
    Ong(
      titulo: "Visita a idosos",
      descricao:
          "Leve companhia e carinho a idosos em asilos. Uma hora do seu tempo transforma o dia de alguém.",
      local: "Curitiba, PR",
      tempo: "1h",
      imagem: "assets/images/imagemensino.jpg",
      categoria: "Idosos",
      nomeOng: "Instituto Viver Bem",
      avaliacao: 4.9,
      totalAvaliacoes: 542,
    ),
    Ong(
      titulo: "Plantio de árvores",
      descricao:
          "Participe do nosso mutirão de reflorestamento urbano. Juntos podemos recuperar áreas degradadas.",
      local: "Belo Horizonte, MG",
      tempo: "3h",
      imagem: "assets/images/imagemjardineiro.png",
      categoria: "Ambientais",
      nomeOng: "Verde Vivo",
      avaliacao: 4.6,
      totalAvaliacoes: 189,
    ),
    Ong(
      titulo: "Tutoria para jovens",
      descricao:
          "Oriente jovens em fase escolar com mentoria de carreira e apoio emocional. Seja um tutor voluntário.",
      local: "Online",
      tempo: "1h 30min",
      imagem: "assets/images/evento.png",
      categoria: "Educação",
      nomeOng: "Conecta Jovem",
      avaliacao: 4.7,
      totalAvaliacoes: 78,
    ),
    Ong(
      titulo: "Adoção responsável",
      descricao:
          "Ajude a encontrar lares para animais resgatados. Faça triagem, fotos e divulgação para adoção.",
      local: "Porto Alegre, RS",
      tempo: "2h",
      imagem: "feira.png",
      categoria: "Animais",
      nomeOng: "Patinhas Felizes",
      avaliacao: 4.4,
      totalAvaliacoes: 260,
    ),
  ];

  List<Ong> get _ongsFiltradas {
    return _todasOngs.where((o) {
      final categoriaOk =
          _categoriaSelecionada == "Todos" ||
          o.categoria == _categoriaSelecionada;
      final buscaOk =
          _busca.isEmpty ||
          o.titulo.toLowerCase().contains(_busca.toLowerCase()) ||
          o.nomeOng.toLowerCase().contains(_busca.toLowerCase());
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

  void _onNavTap(int index) {
    if (index == _bottomNavIndex) return;
    if (index == 0) {
      Navigator.pop(context);
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, __, ___) =>
              Servicos(nome: widget.nome, initialNavIndex: 1),
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
    final filtradas = _ongsFiltradas;

    return Scaffold(
      backgroundColor: _fundo,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroBusca(),
                    const SizedBox(height: 20),

                    // Contador + ações
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            "${filtradas.length} serviços encontrados",
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
                    _chipsCategorias(),
                    const SizedBox(height: 20),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filtradas.length,
                      itemBuilder: (context, index) =>
                          _ongCard(filtradas[index]),
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
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => Login()),
                  (route) => false,
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
            "Encontre serviços solidários e apoie ONGs",
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _branco,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Troque serviços com ONGs e contribua para uma rede solidária que transforma ações voluntárias em impacto social real.",
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
                Icon(
                  Icons.search_rounded,
                  color: _verde.withOpacity(0.5),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _buscaController,
                    onChanged: (v) => setState(() => _busca = v),
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      color: const Color(0xFF344E41),
                    ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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

  // ─── CHIP AÇÃO ────────────────────────────────────────────
  Widget _chipAcao({
    required IconData icone,
    required String label,
    required VoidCallback onTap,
  }) {
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

  // ─── CARD ONG ─────────────────────────────────────────────
  Widget _ongCard(Ong ong) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetalheOng(ong: ong)),
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
            // Imagem placeholder + tag
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: Stack(
                children: [
                  Hero(
                    tag: 'ong_${ong.titulo}',
                    child: Image.asset(
                      ong.imagem,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          height: 170,
                          width: double.infinity,
                          color: const Color(0xFFB7D5B0),
                        );
                      },
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
                        ong.categoria.toUpperCase(),
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

            // Conteúdo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ong.titulo,
                    style: GoogleFonts.quicksand(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2D3319),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ong.descricao,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      color: const Color(0xFF6B705C),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ONG + avaliação
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _verde.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _verde.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: _verde,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ong.nomeOng,
                            style: GoogleFonts.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF344E41),
                            ),
                          ),
                          Row(
                            children: [
                              ...List.generate(5, (i) {
                                if (i < ong.avaliacao.floor()) {
                                  return const Icon(
                                    Icons.star_rounded,
                                    size: 13,
                                    color: Color(0xFFF4A261),
                                  );
                                } else if (i < ong.avaliacao) {
                                  return const Icon(
                                    Icons.star_half_rounded,
                                    size: 13,
                                    color: Color(0xFFF4A261),
                                  );
                                } else {
                                  return const Icon(
                                    Icons.star_border_rounded,
                                    size: 13,
                                    color: Color(0xFFCCCCCC),
                                  );
                                }
                              }),
                              const SizedBox(width: 4),
                              Text(
                                "${ong.avaliacao.toStringAsFixed(1)} (${ong.totalAvaliacoes})",
                                style: GoogleFonts.quicksand(
                                  fontSize: 11,
                                  color: const Color(0xFF6B705C),
                                ),
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
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: _verdeMedio,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          ong.local,
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            color: const Color(0xFF6B705C),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: _verdeMedio,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        ong.tempo,
                        style: GoogleFonts.quicksand(
                          fontSize: 12,
                          color: const Color(0xFF6B705C),
                        ),
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
                        MaterialPageRoute(builder: (_) => DetalheOng(ong: ong)),
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

  // ─── BOTTOM NAV ───────────────────────────────────────────
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
          onTap: _onNavTap,
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
