import 'package:flutter/material.dart';
import 'package:mutuo/widgets/chat_badge_icon.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/notificacoes.dart';
import 'package:mutuo/perfilOng.dart';
import 'package:mutuo/inicialOng.dart';
import 'package:mutuo/servicosOng.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:mutuo/services/auth_service.dart';

class CertificadosOng extends StatefulWidget {
  final String cnpj;
  final String nomeInicial;

  const CertificadosOng({super.key, required this.cnpj, this.nomeInicial = ''});

  @override
  State<CertificadosOng> createState() => _CertificadosOngState();
}

class _CertificadosOngState extends State<CertificadosOng> {
  // ─── Paleta (mesma do resto do app) ───────────────────────
  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;
  static const _cinzaTexto = Color(0xFF6B705C);

  final ApiService _api = ApiService();

  bool _carregando = true;
  Map<String, dynamic> _resumo = {};
  List<dynamic> _servicos = [];
  String? _fotoUrl;

  final TextEditingController _buscaController = TextEditingController();
  String _busca = '';

  int _bottomNavIndex = -1; // certificados não faz parte das 4 abas fixas

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
      _api.buscarCertificadosOng(widget.cnpj),
      _api.buscarFotoPerfilOng(widget.cnpj),
    ]);

    final dados = resultados[0] as Map<String, dynamic>?;
    final foto = resultados[1] as String?;

    if (!mounted) return;
    setState(() {
      _resumo = (dados?['resumo'] as Map<String, dynamic>?) ?? {};
      _servicos = (dados?['servicos'] as List<dynamic>?) ?? [];
      _fotoUrl = foto;
      _carregando = false;
    });
  }

  // ─── helper seguro pra inicial do nome ──
  String get _inicial =>
      widget.nomeInicial.isNotEmpty ? widget.nomeInicial[0].toUpperCase() : 'O';

  String _formatarData(dynamic isoData) {
    if (isoData == null) return '-';
    final data = DateTime.tryParse(isoData.toString());
    if (data == null) return '-';
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  List<dynamic> get _servicosFiltrados {
    if (_busca.trim().isEmpty) return _servicos;
    final termo = _busca.trim().toLowerCase();
    return _servicos.where((s) {
      final nome = (s['nomeUsuario']?.toString() ?? '').toLowerCase();
      return nome.contains(termo);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator(color: _verde))
            : RefreshIndicator(
                onRefresh: _carregarDados,
                color: _verde,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _header(context),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Certificados emitidos',
                            style: GoogleFonts.quicksand(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A2E1B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Histórico de voluntários que concluíram serviços e receberam certificado',
                            style: GoogleFonts.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _cinzaTexto,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _gridResumo(),
                          const SizedBox(height: 24),
                          _cardListaVoluntarios(),
                        ],
                      ),
                    ),
                  ],
                ),
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
      padding: const EdgeInsets.fromLTRB(10, 18, 22, 24),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _branco,
              size: 18,
            ),
          ),
          Text(
            'Certificados',
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _branco,
            ),
          ),
          const Spacer(),
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
                    builder: (_) => PerfilOng(
                      cnpj: widget.cnpj,
                      nomeInicial: widget.nomeInicial,
                    ),
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
                      'Meu Perfil',
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
                      'Sair',
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            child: _avatarCircle(size: 36),
          ),
        ],
      ),
    );
  }

  // ─── AVATAR (foto da ONG com fallback pra iniciais) ────────
  Widget _avatarCircle({required double size}) {
    final foto = _fotoUrl;
    if (foto == null || foto.isEmpty) {
      return _avatarIniciais(size: size);
    }
    return ClipOval(
      child: Image.network(
        '${ApiService.baseUrl}$foto',
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _avatarIniciais(size: size);
        },
        errorBuilder: (context, error, stack) => _avatarIniciais(size: size),
      ),
    );
  }

  Widget _avatarIniciais({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: _bege, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        _inicial,
        style: GoogleFonts.quicksand(
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
          color: _verde,
        ),
      ),
    );
  }

  // ─── GRID DE RESUMO (2x2, igual aos cards do print) ────────
  Widget _gridResumo() {
    final totalVoluntarios = _resumo['totalVoluntarios']?.toString() ?? '0';
    final certificadosEmitidos =
        _resumo['certificadosEmitidos']?.toString() ?? '0';
    final servicosConcluidos = _resumo['servicosConcluidos']?.toString() ?? '0';
    final pontosDistribuidos = _resumo['pontosDistribuidos']?.toString() ?? '0';

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _statCard(
          icone: Icons.groups_outlined,
          titulo: 'Total de\nvoluntários',
          valor: totalVoluntarios,
        ),
        _statCard(
          icone: Icons.workspace_premium_outlined,
          titulo: 'Certificados\nemitidos',
          valor: certificadosEmitidos,
        ),
        _statCard(
          icone: Icons.work_outline_rounded,
          titulo: 'Serviços\nconcluídos',
          valor: servicosConcluidos,
        ),
        _statCard(
          icone: Icons.star_border_rounded,
          titulo: 'Pontos\ndistribuídos',
          valor: pontosDistribuidos,
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0DDD8)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _verde.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: _verde, size: 19),
          ),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: GoogleFonts.quicksand(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _cinzaTexto,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A2E1B),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CARD COM BUSCA + LISTA DE VOLUNTÁRIOS CERTIFICADOS ────
  Widget _cardListaVoluntarios() {
    final filtrados = _servicosFiltrados;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0DDD8)),
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
          Text(
            'Voluntários certificados',
            style: GoogleFonts.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _verde,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _buscaController,
            onChanged: (v) => setState(() => _busca = v),
            style: GoogleFonts.quicksand(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar por nome...',
              hintStyle: GoogleFonts.quicksand(
                fontSize: 13,
                color: const Color(0xFF9AAB96),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF9AAB96),
                size: 20,
              ),
              filled: true,
              fillColor: _fundo,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (filtrados.isEmpty)
            _estadoVazio()
          else
            Column(
              children: filtrados
                  .whereType<Map<String, dynamic>>()
                  .map((s) => _itemVoluntario(s))
                  .toList(),
            ),
          const SizedBox(height: 14),
          Text(
            'Exibindo ${filtrados.length} de ${_servicos.length} certificados',
            style: GoogleFonts.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9AAB96),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemVoluntario(Map<String, dynamic> s) {
    final nome = s['nomeUsuario']?.toString() ?? 'Voluntário';
    final foco = s['foco']?.toString() ?? s['nomeServico']?.toString() ?? '-';
    final data = _formatarData(s['dataConclusao'] ?? s['dataSolicitacao']);
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : 'V';
    final temCertificado = s['codigoVerificacao'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4EBE2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: _bege,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              inicial,
              style: GoogleFonts.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _verde,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A2E1B),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _verde.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        foco,
                        style: GoogleFonts.quicksand(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _verde,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        data,
                        style: GoogleFonts.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _cinzaTexto,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (temCertificado)
            const Icon(
              Icons.workspace_premium_rounded,
              color: _verdeMedio,
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _estadoVazio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 40,
            color: const Color(0xFFB9C4B4),
          ),
          const SizedBox(height: 10),
          Text(
            _busca.trim().isEmpty
                ? 'Nenhum certificado emitido ainda'
                : 'Nenhum voluntário encontrado',
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _cinzaTexto,
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM NAV (mesmo padrão visual do resto do app) ──────
  Widget _buildBottomNav() {
    final navItems = [
      _NavItemCertificadosOng(
        icon: Icons.home_rounded,
        outlinedIcon: Icons.home_outlined,
        label: 'Início',
        onTap: () {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 250),
              pageBuilder: (_, __, ___) =>
                  InicialOng(nome: widget.nomeInicial, cnpj: widget.cnpj),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        },
      ),
      _NavItemCertificadosOng(
        icon: Icons.volunteer_activism_rounded,
        outlinedIcon: Icons.volunteer_activism_outlined,
        label: 'Atividades',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ServicosOng(nome: widget.nomeInicial, cnpj: widget.cnpj),
            ),
          );
        },
      ),
      _NavItemCertificadosOng(
        icon: Icons.assignment_turned_in_rounded,
        outlinedIcon: Icons.assignment_turned_in_outlined,
        label: 'Solicitações',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Notificacoes(
                tipoConta: 'ong',
                identificador: widget.cnpj,
                nome: widget.nomeInicial,
              ),
            ),
          );
        },
      ),
      _NavItemCertificadosOng(
        icon: Icons.chat_bubble_rounded,
        outlinedIcon: Icons.chat_bubble_outline_rounded,
        label: 'Chat',
        onTap: null,
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
          currentIndex: _bottomNavIndex < 0 ? 0 : _bottomNavIndex,
          onTap: (index) {
            final item = navItems[index];
            if (item.onTap != null) {
              item.onTap!();
            } else {
              setState(() => _bottomNavIndex = index);
            }
          },
          backgroundColor: _branco,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedItemColor: _bottomNavIndex < 0
              ? const Color(0xFF9AAB96)
              : _verde,
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
            final isSelected = _bottomNavIndex == index;
            return BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: item.label == 'Chat'
                    ? ChatBadgeIcon(
                        icon: isSelected ? item.icon : item.outlinedIcon,
                      )
                    : Icon(
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

class _NavItemCertificadosOng {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final VoidCallback? onTap;

  _NavItemCertificadosOng({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    this.onTap,
  });
}
