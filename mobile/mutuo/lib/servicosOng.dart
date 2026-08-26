import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/inicialOng.dart';
import 'package:mutuo/perfilOng.dart';
import 'package:mutuo/planosOng.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:mutuo/widgets/modal_atividade_ong.dart';
import 'package:mutuo/services/auth_service.dart';

class ServicosOng extends StatefulWidget {
  final String nome;
  final String cnpj;

  const ServicosOng({super.key, required this.nome, required this.cnpj});

  @override
  State<ServicosOng> createState() => _ServicosOngState();
}

class _ServicosOngState extends State<ServicosOng> {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _ong;
  List<dynamic> _atividades = [];
  bool _carregando = true;

  String _categoriaSelecionada = "Todos";
  final TextEditingController _buscaController = TextEditingController();
  String _busca = "";

  int _bottomNavIndex = 1;

  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  bool get _limiteAtingido =>
      (_ong?['premium'] != 1) && _atividades.length >= 3;

  List<String> get _categorias {
    final focosUnicos =
        _atividades
            .whereType<Map<String, dynamic>>()
            .map((a) => a['foco']?.toString() ?? '')
            .where((f) => f.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ["Todos", ...focosUnicos];
  }

  List<Map<String, dynamic>> get _atividadesFiltradas {
    return _atividades.whereType<Map<String, dynamic>>().where((a) {
      final foco = a['foco']?.toString() ?? '';
      final nome = a['nomeServico']?.toString() ?? '';
      final categoriaOk =
          _categoriaSelecionada == "Todos" || foco == _categoriaSelecionada;
      final buscaOk =
          _busca.isEmpty || nome.toLowerCase().contains(_busca.toLowerCase());
      return categoriaOk && buscaOk;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    final resultados = await Future.wait([
      _api.buscarOngPorCnpj(widget.cnpj),
      _api.buscarServicosOng(widget.cnpj),
    ]);

    if (!mounted) return;

    final ong = resultados[0] as Map<String, dynamic>?;
    final atividades = resultados[1] as List<dynamic>;

    setState(() {
      _ong = ong;
      _atividades = atividades;
      _carregando = false;
      if (!_categorias.contains(_categoriaSelecionada)) {
        _categoriaSelecionada = "Todos";
      }
    });
  }

  Future<void> _excluirAtividade(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Excluir atividade',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Tem certeza que deseja excluir esta atividade?',
          style: GoogleFonts.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.quicksand(color: const Color(0xFF6B705C)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Excluir',
              style: GoogleFonts.quicksand(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final resultado = await _api.excluirServicoOng(id);
    if (!mounted) return;

    if (resultado['sucesso'] == false && resultado['erro'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultado['erro'])));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Atividade excluída com sucesso!')),
    );
    _carregarDados();
  }

  void _onNavTap(int index) {
    if (index == _bottomNavIndex) return;
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, __, ___) => InicialOng(
            nome: _ong?['nomeOng'] ?? widget.nome,
            cnpj: widget.cnpj,
          ),
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
    final filtradas = _atividadesFiltradas;

    return Scaffold(
      backgroundColor: _fundo,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator(color: _verde))
            : RefreshIndicator(
                color: _verde,
                onRefresh: _carregarDados,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(context),
                      const SizedBox(height: 20),
                      _heroTopo(),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Text(
                              "${filtradas.length} atividades encontradas",
                              style: GoogleFonts.quicksand(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B705C),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _limiteAtingido
                                  ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PlanosOng(
                                          cnpj: widget.cnpj,
                                          nomeInicial: widget.nome,
                                        ),
                                      ),
                                    )
                                  : () => abrirModalAtividadeOng(
                                      context: context,
                                      cnpj: widget.cnpj,
                                      onSucesso: _carregarDados,
                                    ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: _limiteAtingido
                                      ? Colors.redAccent
                                      : _verde,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _limiteAtingido
                                          ? Icons.workspace_premium_outlined
                                          : Icons.add,
                                      size: 15,
                                      color: _branco,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _limiteAtingido
                                          ? "Ver planos"
                                          : "Adicionar",
                                      style: GoogleFonts.quicksand(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _branco,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _chipsCategorias(),
                      const SizedBox(height: 18),
                      if (_limiteAtingido)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Limite de 3 atividades do plano gratuito consumido. Faça upgrade pra cadastrar mais.',
                                    style: GoogleFonts.quicksand(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (filtradas.isEmpty)
                        _estadoVazio()
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: filtradas
                                .map((a) => _cardAtividade(a))
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────
  Widget _header(BuildContext context) {
    final nomeOng =
        _ong?['nomeOng']?.toString() ??
        (widget.nome.isNotEmpty ? widget.nome : 'ONG');

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
            onSelected: (value) async {
              if (value == 'logout') {
                await AuthService.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const Login()),
                  (route) => false,
                );
              } else if (value == 'meu_perfil') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PerfilOng(cnpj: widget.cnpj, nomeInicial: widget.nome),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _verdeMedio.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: _bege,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      nomeOng.isNotEmpty ? nomeOng[0].toUpperCase() : "O",
                      style: GoogleFonts.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _verde,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: Text(
                      nomeOng,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _branco,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BLOCO DE TÍTULO + BUSCA ────────────────────────────────
  Widget _heroTopo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: _verde,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Minhas atividades",
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _branco,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Gerencie as oportunidades de voluntariado que sua ONG oferece.",
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
                      hintText: "Buscar atividade...",
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
                const SizedBox(width: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CHIPS DE CATEGORIA ───────────────────────────────────
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

  // ─── ESTADO VAZIO ─────────────────────────────────────────
  Widget _estadoVazio() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
              Icons.inbox_outlined,
              size: 36,
              color: Color(0xFFB9C4B4),
            ),
            const SizedBox(height: 10),
            Text(
              "Nenhuma atividade encontrada",
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

  // ─── CARD DE ATIVIDADE (com editar/excluir) ──────────────
  Widget _cardAtividade(Map<String, dynamic> atividade) {
    final nome = atividade['nomeServico']?.toString() ?? 'Atividade sem nome';
    final descricao = atividade['descricao']?.toString() ?? '';
    final foco = atividade['foco']?.toString() ?? '';
    final horas = atividade['horas']?.toString() ?? '';
    final imagem = atividade['imagem']?.toString();
    final imagemUrl = (imagem != null && imagem.isNotEmpty)
        ? '${ApiService.baseUrl}$imagem'
        : null;
    final id = atividade['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: imagemUrl != null
                ? Image.network(
                    imagemUrl,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 130,
                      width: double.infinity,
                      color: _bege,
                      child: const Icon(
                        Icons.volunteer_activism_outlined,
                        color: _verde,
                        size: 36,
                      ),
                    ),
                  )
                : Container(
                    height: 130,
                    width: double.infinity,
                    color: _bege,
                    child: const Icon(
                      Icons.volunteer_activism_outlined,
                      color: _verde,
                      size: 36,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nome,
                        style: GoogleFonts.quicksand(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A2E1B),
                        ),
                      ),
                    ),
                    if (foco.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _verde.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          foco,
                          style: GoogleFonts.quicksand(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _verde,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    color: const Color(0xFF6B705C),
                    height: 1.4,
                  ),
                ),
                if (horas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: _verdeMedio,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$horas horas",
                        style: GoogleFonts.quicksand(
                          fontSize: 12,
                          color: const Color(0xFF6B705C),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _verde,
                          side: BorderSide(color: _verde.withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => abrirModalAtividadeOng(
                          context: context,
                          cnpj: widget.cnpj,
                          atividade: atividade,
                          onSucesso: _carregarDados,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(
                          "Editar",
                          style: GoogleFonts.quicksand(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(
                            color: Colors.redAccent.withOpacity(0.4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _excluirAtividade(id),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                        ),
                        label: Text(
                          "Excluir",
                          style: GoogleFonts.quicksand(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM NAV ───────────────────────────────────────────
  Widget _buildBottomNav() {
    final navItems = [
      _NavItemServicosOng(
        icon: Icons.home_rounded,
        outlinedIcon: Icons.home_outlined,
        label: 'Início',
      ),
      _NavItemServicosOng(
        icon: Icons.volunteer_activism_rounded,
        outlinedIcon: Icons.volunteer_activism_outlined,
        label: 'Atividades',
      ),
      _NavItemServicosOng(
        icon: Icons.assignment_turned_in_rounded,
        outlinedIcon: Icons.assignment_turned_in_outlined,
        label: 'Solicitações',
      ),
      _NavItemServicosOng(
        icon: Icons.chat_bubble_rounded,
        outlinedIcon: Icons.chat_bubble_outline_rounded,
        label: 'Chat',
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
          unselectedItemColor: const Color(0xFF9AAB96),
          selectedLabelStyle: GoogleFonts.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          items: List.generate(navItems.length, (index) {
            final item = navItems[index];
            final isSelected = index == _bottomNavIndex;
            return BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
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

class _NavItemServicosOng {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;

  _NavItemServicosOng({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
  });
}
