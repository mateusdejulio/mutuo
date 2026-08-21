import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/ongs.dart';
import 'package:mutuo/quem_somos.dart';
import 'package:mutuo/widgets/avatar_perfil.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:mutuo/services/api_service.dart';

// ─── MODEL ────────────────────────────────────────────────
// Representa um serviço vindo do banco (rota /servicos-usuario)
// ─── MODEL ────────────────────────────────────────────────
class Servico {
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

  Servico({
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

  factory Servico.fromJson(Map<String, dynamic> json) {
    final horas = json['qtdHoras'];
    final caminhoImagem = json['imagem']?.toString();
    return Servico(
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

// ─── DETALHE SERVIÇO ──────────────────────────────────────
class DetalheServico extends StatelessWidget {
  final Servico servico;

  const DetalheServico({super.key, required this.servico});

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
                  tag: 'servico_${servico.id}',
                  child: servico.imagemUrl != null
                      ? Image.network(
                          servico.imagemUrl!,
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
                      servico.categoria.toUpperCase(),
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
                          "${servico.pontos} pts",
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
                      servico.titulo,
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
                          servico.autor,
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
                          servico.local,
                          style: GoogleFonts.quicksand(fontSize: 13, color: const Color(0xFF6B705C)),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time_rounded, size: 16, color: _verdeMedio),
                        const SizedBox(width: 4),
                        Text(
                          servico.tempo,
                          style: GoogleFonts.quicksand(fontSize: 13, color: const Color(0xFF6B705C)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(height: 1, color: const Color(0xFFEDEAE5)),
                    const SizedBox(height: 22),
                    Text(
                      "Sobre o serviço",
                      style: GoogleFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF344E41),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      servico.descricao,
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
                                const SnackBar(content: Text("Interesse registrado!")),
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: Text(
                              "Solicitar",
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

// ─── TELA SERVIÇOS ────────────────────────────────────────
class Servicos extends StatefulWidget {
  final String nome;
  final String cpf;
  final int initialNavIndex;

  const Servicos({super.key, required this.nome, required this.cpf, this.initialNavIndex = 1});

  @override
  State<Servicos> createState() => _ServicosState();
}

class _ServicosState extends State<Servicos> {
  late int _bottomNavIndex;
  String _categoriaSelecionada = "Todos";
  final TextEditingController _buscaController = TextEditingController();
  String _busca = "";

  final ApiService _apiService = ApiService();
  List<Servico> _todosServicos = [];
  bool _carregando = true;

  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  // ─── NOVO: categorias montadas dinamicamente a partir dos serviços cadastrados ───
  List<String> get _categorias {
    final focosUnicos = _todosServicos
        .map((s) => s.categoria)
        .where((f) => f.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ["Todos", ...focosUnicos];
  }

  List<Servico> get _servicosFiltrados {
    return _todosServicos.where((s) {
      final categoriaOk =
          _categoriaSelecionada == "Todos" ||
          s.categoria == _categoriaSelecionada;
      final buscaOk =
          _busca.isEmpty ||
          s.titulo.toLowerCase().contains(_busca.toLowerCase()) ||
          s.autor.toLowerCase().contains(_busca.toLowerCase());
      return categoriaOk && buscaOk;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _bottomNavIndex = widget.initialNavIndex;
    _carregarServicos();
  }

  // ─── Busca os serviços reais na API ───
  Future<void> _carregarServicos() async {
    final dados = await _apiService.buscarTodosServicos();
    if (!mounted) return;

    setState(() {
      _todosServicos = dados
          .whereType<Map<String, dynamic>>()
          .map((json) => Servico.fromJson(json))
          .toList();
      _carregando = false;

      // Se a categoria selecionada não existe mais na lista atual, volta pra "Todos"
      if (!_categorias.contains(_categoriaSelecionada)) {
        _categoriaSelecionada = "Todos";
      }
    });
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
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, __, ___) =>
              Ongs(nome: widget.nome, cpf: widget.cpf, initialNavIndex: 2),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
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
                            _carregando
                                ? "Carregando serviços..."
                                : "${filtrados.length} serviços encontrados",
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
                    if (!_carregando) _chipsCategorias(),
                    const SizedBox(height: 20),

                    if (_carregando)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: CircularProgressIndicator(color: _verde),
                        ),
                      )
                    else if (filtrados.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 40,
                        ),
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
                              const Icon(
                                Icons.search_off_rounded,
                                color: _verdeMedio,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Nenhum serviço encontrado",
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
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: filtrados.length,
                        itemBuilder: (context, index) =>
                            _servicoCard(filtrados[index]),
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
            "Encontre serviços e troque habilidades",
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _branco,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Ofereça o que você sabe e receba o que precisa. Uma rede de trocas solidárias que valoriza cada talento.",
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

  // ─── CHIPS CATEGORIAS (agora dinâmicas, vindas do banco) ───
  Widget _chipsCategorias() {
    final categorias = _categorias;

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categorias.length,
        itemBuilder: (context, index) {
          final cat = categorias[index];
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
            // Imagem + tag
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: Stack(
                children: [
                  Hero(
                    tag: 'servico_${servico.id}',
                    child: servico.imagemUrl != null
                        ? Image.network(
                            servico.imagemUrl!,
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 170,
                                width: double.infinity,
                                color: const Color(0xFFB7D5B0),
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.white54,
                                  size: 56,
                                ),
                              );
                            },
                          )
                        : Container(
                            height: 170,
                            width: double.infinity,
                            color: const Color(0xFFB7D5B0),
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.white54,
                              size: 56,
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

            // Conteúdo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    servico.titulo,
                    style: GoogleFonts.quicksand(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2D3319),
                    ),
                  ),
                  const SizedBox(height: 4),
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

                  // Autor
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
                          Icons.person_rounded,
                          color: _verde,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          servico.autor,
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF344E41),
                          ),
                        ),
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
                          servico.local,
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
                        servico.tempo,
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
                        MaterialPageRoute(
                          builder: (_) => DetalheServico(servico: servico),
                        ),
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