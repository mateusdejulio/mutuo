import 'package:flutter/material.dart';
import 'package:mutuo/widgets/chat_badge_icon.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/perfil.dart';
import 'package:mutuo/inicialUser.dart';
import 'package:mutuo/servicos.dart';
import 'package:mutuo/ongs.dart';
import 'package:mutuo/widgets/avatar_perfil.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:mutuo/services/auth_service.dart';

class CertificadosUsuario extends StatefulWidget {
  final String cpf;
  final String nomeInicial;

  const CertificadosUsuario({
    super.key,
    required this.cpf,
    this.nomeInicial = '',
  });

  @override
  State<CertificadosUsuario> createState() => _CertificadosUsuarioState();
}

class _CertificadosUsuarioState extends State<CertificadosUsuario> {
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

  // codSolicitacao dos certificados que estão sendo gerados agora
  final Set<String> _gerando = {};

  int _bottomNavIndex = -1; // certificados não faz parte das 4 abas fixas

  static const List<String> _meses = [
    'JANEIRO',
    'FEVEREIRO',
    'MARÇO',
    'ABRIL',
    'MAIO',
    'JUNHO',
    'JULHO',
    'AGOSTO',
    'SETEMBRO',
    'OUTUBRO',
    'NOVEMBRO',
    'DEZEMBRO',
  ];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    final dados = await _api.buscarCertificadosUsuario(widget.cpf);
    if (!mounted) return;
    setState(() {
      _resumo = (dados?['resumo'] as Map<String, dynamic>?) ?? {};
      _servicos = (dados?['servicos'] as List<dynamic>?) ?? [];
      _carregando = false;
    });
  }

  String get _inicial =>
      widget.nomeInicial.isNotEmpty ? widget.nomeInicial[0].toUpperCase() : 'U';

  String _formatarData(dynamic isoData) {
    if (isoData == null) return '-';
    final data = DateTime.tryParse(isoData.toString());
    if (data == null) return '-';
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  // ─── Agrupa os serviços por "MÊS ANO", preservando a ordem
  // (o backend já manda ordenado do mais recente pro mais antigo) ───
  List<MapEntry<String, List<Map<String, dynamic>>>> get _gruposPorMes {
    final Map<String, List<Map<String, dynamic>>> grupos = {};
    for (final item in _servicos) {
      if (item is! Map<String, dynamic>) continue;
      final isoData = item['dataConclusao'] ?? item['dataSolicitacao'];
      final data = DateTime.tryParse(isoData?.toString() ?? '');
      final chave = data != null
          ? '${_meses[data.month - 1]} ${data.year}'
          : 'DATA NÃO INFORMADA';
      grupos.putIfAbsent(chave, () => []).add(item);
    }
    return grupos.entries.toList();
  }

  // ─── Abre o PDF real do certificado (rota já existe no backend) ───
  Future<void> _gerarCertificado(String codSolicitacao) async {
    setState(() => _gerando.add(codSolicitacao));

    final uri = Uri.parse(
      '${ApiService.baseUrl}/certificados/${Uri.encodeComponent(widget.cpf)}/$codSolicitacao/pdf',
    );

    try {
      final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abriu && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o certificado.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar certificado: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _gerando.remove(codSolicitacao));
    }
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
                            'Meus certificados',
                            style: GoogleFonts.quicksand(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A2E1B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Serviços voluntários concluídos e disponíveis para download',
                            style: GoogleFonts.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _cinzaTexto,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _linhaResumo(),
                          const SizedBox(height: 26),
                          Text(
                            'Serviços concluídos',
                            style: GoogleFonts.quicksand(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _verde,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_servicos.isEmpty)
                            _estadoVazio()
                          else
                            ..._gruposPorMes.map(_blocoMes),
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
                    builder: (_) => PerfilUsuario(
                      cpf: widget.cpf,
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
            child: AvatarPerfil(
              cpf: widget.cpf,
              nome: widget.nomeInicial,
              radius: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ─── LINHA DE RESUMO (3 cards, igual ao print) ─────────────
  Widget _linhaResumo() {
    final servicosConcluidos = _resumo['servicosConcluidos']?.toString() ?? '0';
    final ongsAjudadas = _resumo['ongsAjudadas']?.toString() ?? '0';
    final pontos = _resumo['pontos']?.toString() ?? '0';

    return Row(
      children: [
        Expanded(
          child: _statCard(
            icone: Icons.work_outline_rounded,
            titulo: 'Serviços\nconcluídos',
            valor: servicosConcluidos,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icone: Icons.groups_outlined,
            titulo: 'ONGs\najudadas',
            valor: ongsAjudadas,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icone: Icons.bolt_rounded,
            titulo: 'Pontos\nacumulados',
            valor: pontos,
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _verde.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: _verde, size: 17),
          ),
          const SizedBox(height: 8),
          Text(
            titulo,
            style: GoogleFonts.quicksand(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: _cinzaTexto,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            valor,
            style: GoogleFonts.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A2E1B),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BLOCO DE UM MÊS (rótulo + cards do mês) ───────────────
  Widget _blocoMes(MapEntry<String, List<Map<String, dynamic>>> grupo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            grupo.key,
            style: GoogleFonts.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF9AAB96),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          ...grupo.value.map(_cardServico),
        ],
      ),
    );
  }

  Widget _cardServico(Map<String, dynamic> s) {
    final codSolicitacao = s['codSolicitacao']?.toString() ?? '';
    final nomeServico = s['nomeServico']?.toString() ?? 'Serviço';
    final nomeOng = s['nomeOng']?.toString() ?? '';
    final horas = s['horas']?.toString() ?? '0';
    final pontos = s['pontosSolicitacao']?.toString() ?? '0';
    final data = _formatarData(s['dataConclusao'] ?? s['dataSolicitacao']);
    final gerandoEste = _gerando.contains(codSolicitacao);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0DDD8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _verde.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: _verde,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomeServico,
                      style: GoogleFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A2E1B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nomeOng,
                      style: GoogleFonts.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _cinzaTexto,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: _verdeMedio,
              ),
              const SizedBox(width: 4),
              Text(
                '${horas}h',
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _cinzaTexto,
                ),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.bolt_rounded, size: 14, color: _verdeMedio),
              const SizedBox(width: 4),
              Text(
                '$pontos pts',
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _cinzaTexto,
                ),
              ),
              const Spacer(),
              Text(
                data,
                style: GoogleFonts.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9AAB96),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                foregroundColor: _branco,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: codSolicitacao.isEmpty || gerandoEste
                  ? null
                  : () => _gerarCertificado(codSolicitacao),
              icon: gerandoEste
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _branco,
                      ),
                    )
                  : const Icon(Icons.file_download_outlined, size: 18),
              label: Text(
                gerandoEste ? 'Gerando...' : 'Gerar certificado',
                style: GoogleFonts.quicksand(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoVazio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          const Icon(
            Icons.workspace_premium_outlined,
            size: 40,
            color: Color(0xFFB9C4B4),
          ),
          const SizedBox(height: 10),
          Text(
            'Você ainda não concluiu nenhum serviço voluntário',
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

  // ─── BOTTOM NAV (padronizado com inicialUser.dart) ─────────
  Widget _buildBottomNav() {
    final navItems = [
      _NavItemCertificadosUsuario(
        icon: Icons.home_rounded,
        outlinedIcon: Icons.home_outlined,
        label: 'Início',
        onTap: () {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 250),
              pageBuilder: (_, __, ___) =>
                  InicialUsuario(nome: widget.nomeInicial, cpf: widget.cpf),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        },
      ),
      _NavItemCertificadosUsuario(
        icon: Icons.work_rounded,
        outlinedIcon: Icons.work_outline_rounded,
        label: 'Serviços',
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 250),
              pageBuilder: (_, __, ___) => Servicos(
                nome: widget.nomeInicial,
                cpf: widget.cpf,
                initialNavIndex: 1,
              ),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        },
      ),
      _NavItemCertificadosUsuario(
        icon: Icons.favorite_rounded,
        outlinedIcon: Icons.favorite_border_rounded,
        label: 'ONGs',
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 250),
              pageBuilder: (_, __, ___) => Ongs(
                nome: widget.nomeInicial,
                cpf: widget.cpf,
                initialNavIndex: 2,
              ),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        },
      ),
      _NavItemCertificadosUsuario(
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
              ? const Color(0xFFADB5BD)
              : _verde,
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

class _NavItemCertificadosUsuario {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final VoidCallback? onTap;

  _NavItemCertificadosUsuario({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    this.onTap,
  });
}
