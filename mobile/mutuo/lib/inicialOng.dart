import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/perfilOng.dart';
import 'package:mutuo/planosOng.dart';
import 'package:mutuo/certificadosOng.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:mutuo/widgets/modal_atividade_ong.dart';
import 'package:mutuo/servicosOng.dart';

class InicialOng extends StatefulWidget {
  final String nome;
  final String cnpj;

  const InicialOng({super.key, required this.nome, required this.cnpj});

  @override
  State<InicialOng> createState() => _InicialOngState();
}

class _InicialOngState extends State<InicialOng> {
  int _fraseIndex = 0;

  final ApiService _apiService = ApiService();

  Map<String, dynamic>? _ong;
  List<dynamic> _atividades = [];
  int _totalVoluntarios = 0;
  bool _carregando = true;
  String? _fotoUrl;
  int _bottomNavIndex = 0;

  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  final List<String> _frases = [
    "Solidariedade é transformar empatia em ação.",
    "Juntos, podemos construir um futuro mais humano.",
    "Pequenos gestos transformam grandes realidades.",
  ];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final resultados = await Future.wait([
      _apiService.buscarOngPorCnpj(widget.cnpj),
      _apiService.buscarServicosOng(widget.cnpj),
      _apiService.buscarSolicitacoesOng(widget.cnpj),
      _apiService.buscarFotoPerfilOng(widget.cnpj),
    ]);

    if (!mounted) return;

    final ong = resultados[0] as Map<String, dynamic>?;
    final atividades = resultados[1] as List<dynamic>;
    final solicitacoes = resultados[2] as List<dynamic>;
    final foto = resultados[3] as String?;

    // Conta voluntários distintos que já solicitaram algum serviço da ONG.
    // Não existe rota de "voluntários únicos" pronta, então calculo aqui
    // em cima das solicitações recebidas.
    final cpfsUnicos = solicitacoes
        .whereType<Map<String, dynamic>>()
        .map((s) => s['cpfSolicitador']?.toString())
        .where((cpf) => cpf != null && cpf.isNotEmpty)
        .toSet();

    setState(() {
      _ong = ong;
      _atividades = atividades;
      _totalVoluntarios = cpfsUnicos.length;
      _fotoUrl = foto;
      _carregando = false;
    });
  }

  String get _nomeOng =>
      _ong?['nomeOng']?.toString() ??
      (widget.nome.isNotEmpty ? widget.nome : 'ONG');

  String get _inicial => _nomeOng.isNotEmpty ? _nomeOng[0].toUpperCase() : "O";

  // Plano gratuito: até 3 atividades ativas. ONGs premium (campo `premium`
  // vindo do banco) não têm esse limite.
  bool get _limiteAtingido =>
      (_ong?['premium'] != 1) && _atividades.length >= 3;

  String get _localizacao {
    final cidade = _ong?['cidade']?.toString() ?? '';
    final estado = _ong?['estado']?.toString() ?? '';
    if (cidade.isEmpty && estado.isEmpty) return '';
    if (estado.isEmpty) return cidade;
    if (cidade.isEmpty) return estado;
    return '$cidade, $estado';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _buildBottomNav(),
      backgroundColor: _fundo,
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _cardBoasVindas(),
                            const SizedBox(height: 24),
                            _cardPerfilOng(),
                            const SizedBox(height: 24),
                            _cardFrase(),
                            const SizedBox(height: 28),
                            _sectionTitle("Acesso rápido"),
                            const SizedBox(height: 14),
                            _gridAcessoRapido(),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _sectionTitle("Adicionados recentemente"),
                                GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Em breve: lista completa de atividades",
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Ver todos →",
                                    style: GoogleFonts.quicksand(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _verdeMedio,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _atividades.isEmpty
                                ? _estadoVazioAtividades()
                                : Column(
                                    children: _atividades
                                        .whereType<Map<String, dynamic>>()
                                        .map((a) => _cardAtividade(a))
                                        .toList(),
                                  ),
                            const SizedBox(height: 18),
                            _cardAdicionarAtividade(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─── BOTTOM NAV (mesmo padrão visual do resto do app) ──────
  // "Atividades", "Solicitações" e "Chat" ainda não têm tela própria
  // pra ONG — ficam com onTap: null por enquanto, igual o "Chat" já
  // funciona hoje em inicialUser.dart (só realça a aba, sem navegar
  // pra lugar nenhum e sem quebrar nada).
  Widget _buildBottomNav() {
    final navItems = [
      _NavItemOng(
        icon: Icons.home_rounded,
        outlinedIcon: Icons.home_outlined,
        label: 'Início',
        onTap: null,
      ),
      _NavItemOng(
        icon: Icons.volunteer_activism_rounded,
        outlinedIcon: Icons.volunteer_activism_outlined,
        label: 'Atividades',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServicosOng(
                nome: _ong?['nomeOng'] ?? widget.nome,
                cnpj: widget.cnpj,
              ),
            ),
          );
        },
      ),
      _NavItemOng(
        icon: Icons.assignment_turned_in_rounded,
        outlinedIcon: Icons.assignment_turned_in_outlined,
        label: 'Solicitações',
        onTap: null,
      ),
      _NavItemOng(
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
          currentIndex: _bottomNavIndex,
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
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 24),
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
          // TODO: badge de notificações fixo — ainda não existe rota de contagem real.
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
                  _avatarCircle(size: 28),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: Text(
                      _nomeOng,
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

  // ─── AVATAR (foto da ONG com fallback pra iniciais) ─────
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
                  "Bem-vindo(a), $_nomeOng!",
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

  // ─── CARD PERFIL/RESUMO DA ONG (card verde grande) ─────────
  Widget _cardPerfilOng() {
    final pontos = _ong?['pontos'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
      decoration: BoxDecoration(
        color: _verde,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _nomeOng,
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _branco,
            ),
          ),
          const SizedBox(height: 10),
                    Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_localizacao.isNotEmpty)
                _badgeClaro(
                  icone: Icons.location_on_outlined,
                  texto: _localizacao,
                ),
              // Badge só aparece pra ONGs com plano Premium ativo.
              if (_ong?['premium'] == 1)
                _badgeClaro(
                  icone: Icons.verified_outlined,
                  texto: "ONG verificada",
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _statTopoOng(valor: "$_totalVoluntarios", label: "VOLUNTÁRIOS"),
              // Avaliação média ainda não tem coluna/rota no backend pra serviços de ONG.
              _statTopoOng(valor: "—", label: "AVALIAÇÃO"),
            ],
          ),
          const SizedBox(height: 14),
          _statTopoOng(
            valor: "${_atividades.length}",
            label: "ATIVIDADES",
            largura: double.infinity,
          ),
          const SizedBox(height: 22),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _branco.withOpacity(0.4), width: 2),
                ),
                padding: const EdgeInsets.all(6),
                child: _avatarCircle(size: 72),
              ),
              Positioned(
                bottom: 2,
                right: 120,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: _branco,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 16, color: _verde),
                ),
              ),
            ],
          ),
          if (pontos != null) ...[
            const SizedBox(height: 14),
            Text(
              "$pontos pontos acumulados",
              style: GoogleFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _branco.withOpacity(0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badgeClaro({required IconData icone, required String texto}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _branco.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: _branco),
          const SizedBox(width: 6),
          Text(
            texto,
            style: GoogleFonts.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _branco,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTopoOng({
    required String valor,
    required String label,
    double? largura,
  }) {
    final conteudo = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _branco.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text(
            valor,
            style: GoogleFonts.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _branco,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.quicksand(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _branco.withOpacity(0.75),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );

    if (largura == double.infinity) {
      return SizedBox(width: double.infinity, child: conteudo);
    }
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: conteudo,
      ),
    );
  }

  // ─── CARD FRASE (carrossel simples) ───────────────────────
  Widget _cardFrase() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bege,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            '"${_frases[_fraseIndex]}"',
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B705C),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_frases.length, (i) {
              return GestureDetector(
                onTap: () => setState(() => _fraseIndex = i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _fraseIndex == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _fraseIndex == i
                        ? _verdeMedio
                        : _verde.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
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

  // ─── ACESSO RÁPIDO ────────────────────────────────────────
  Widget _gridAcessoRapido() {
    final itens = [
      _AcessoOngData(
        icone: Icons.person_outline_rounded,
        label: "Meu Perfil",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PerfilOng(cnpj: widget.cnpj, nomeInicial: widget.nome),
            ),
          );
        },
      ),
      _AcessoOngData(
        icone: Icons.notifications_none_rounded,
        label: "Notificações",
        badge: 3, // TODO: sem rota de contagem real ainda — valor fixo
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Em breve: central de notificações")),
        ),
      ),
      _AcessoOngData(
        icone: Icons.diamond_outlined,
        label: "Nossos Planos",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PlanosOng(cnpj: widget.cnpj, nomeInicial: widget.nome),
            ),
          );
        },
      ),
      _AcessoOngData(
        icone: Icons.person_outline_rounded,
        label: "Meu Perfil",
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Em breve: tela de perfil da ONG")),
        ),
      ),
      _AcessoOngData(
        icone: Icons.workspace_premium_outlined,
        label: "Certificados",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CertificadosOng(cnpj: widget.cnpj, nomeInicial: widget.nome),
            ),
          );
        },
      ),
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

  Widget _acessoCard(_AcessoOngData item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _branco,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE0DDD8)),
        ),
        padding: const EdgeInsets.all(14),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _verde.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icone, color: _verde, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  item.label,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF344E41),
                  ),
                ),
              ],
            ),
            if (item.badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
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
      ),
    );
  }

  // ─── ESTADO VAZIO (sem atividades cadastradas) ─────────────
  Widget _estadoVazioAtividades() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: Color(0xFFB9C4B4)),
          const SizedBox(height: 10),
          Text(
            "Você ainda não cadastrou nenhuma atividade.",
            style: GoogleFonts.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9AAB96),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CARD DE UMA ATIVIDADE JÁ CADASTRADA ───────────────────
  Widget _cardAtividade(Map<String, dynamic> atividade) {
    final nome = atividade['nomeServico']?.toString() ?? 'Atividade sem nome';
    final descricao = atividade['descricao']?.toString() ?? '';
    final imagem = atividade['imagem']?.toString();
    final imagemUrl = (imagem != null && imagem.isNotEmpty)
        ? '${ApiService.baseUrl}$imagem'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0DDD8)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imagemUrl != null
                ? Image.network(
                    imagemUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: _bege,
                    child: const Icon(
                      Icons.volunteer_activism_outlined,
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
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A2E1B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    color: const Color(0xFF6B705C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CARD "ADICIONAR NOVA ATIVIDADE" ───────────────────────
  Widget _cardAdicionarAtividade() {
    final limiteAtingido = _limiteAtingido;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: limiteAtingido
              ? Colors.redAccent.withOpacity(0.3)
              : const Color(0xFFE0DDD8),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 90,
            decoration: BoxDecoration(
              color: limiteAtingido
                  ? Colors.redAccent.withOpacity(0.08)
                  : _fundo,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              limiteAtingido ? Icons.lock_outline_rounded : Icons.add,
              size: 30,
              color: limiteAtingido
                  ? Colors.redAccent
                  : const Color(0xFFB9C4B4),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            limiteAtingido
                ? "Limite de atividades atingido"
                : "Adicionar nova atividade",
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A2E1B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            limiteAtingido
                ? "Seu plano gratuito permite até 3 atividades ativas. Faça upgrade pra cadastrar mais."
                : "Crie uma nova oportunidade de voluntariado para engajar mais pessoas na sua causa.",
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: const Color(0xFF6B705C),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Plano gratuito: ${_atividades.length}/3 atividades",
            style: GoogleFonts.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: limiteAtingido
                  ? Colors.redAccent
                  : const Color(0xFF9AAB96),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: limiteAtingido ? Colors.redAccent : _verde,
                foregroundColor: _branco,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: limiteAtingido
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
                      totalAtividades: _atividades.length,
                      ongPremium: _ong?['premium'] == 1,
                    ),
              icon: Icon(
                limiteAtingido
                    ? Icons.workspace_premium_outlined
                    : Icons.add_circle_outline_rounded,
                size: 18,
              ),
              label: Text(
                limiteAtingido ? "Ver planos" : "Criar atividade",
                style: GoogleFonts.quicksand(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItemOng {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final VoidCallback? onTap;

  _NavItemOng({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    this.onTap,
  });
}

// ─── DATA CLASS AUXILIAR ──────────────────────────────────
class _AcessoOngData {
  final IconData icone;
  final String label;
  final int? badge;
  final VoidCallback? onTap;

  _AcessoOngData({
    required this.icone,
    required this.label,
    this.badge,
    this.onTap,
  });
}
