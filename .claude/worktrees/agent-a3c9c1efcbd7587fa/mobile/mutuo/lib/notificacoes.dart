import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/chat.dart';
import 'package:mutuo/conversaChat.dart';
import 'package:mutuo/inicialOng.dart';
import 'package:mutuo/inicialUser.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/ongs.dart';
import 'package:mutuo/perfil.dart';
import 'package:mutuo/perfilOng.dart';
import 'package:mutuo/quem_somos.dart';
import 'package:mutuo/servicos.dart';
import 'package:mutuo/servicosOng.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:mutuo/services/auth_service.dart';
import 'package:mutuo/services/solicitacao_sessao_service.dart';
import 'package:mutuo/widgets/chat_badge_icon.dart';

// ─── TELA DE NOTIFICAÇÕES / SOLICITAÇÕES ───────────────────
// Mostra as solicitações de serviço recebidas pela conta logada:
// - usuário: solicitações de outros usuários pros serviços que ele presta
//   (GET /solicitacoes/prestador/:cpf).
// - ong: solicitações de voluntários pras atividades da ONG
//   (GET /solicitacoes-ong/prestador/:cnpj).
// Acessível pelo sino de notificações (em várias telas) e, no caso da ONG,
// também pela aba "Solicitações" da navBar.
class Notificacoes extends StatefulWidget {
  final String tipoConta; // 'usuario' ou 'ong'
  final String identificador; // cpf ou cnpj
  final String nome;

  const Notificacoes({
    super.key,
    required this.tipoConta,
    required this.identificador,
    required this.nome,
  });

  @override
  State<Notificacoes> createState() => _NotificacoesState();
}

class _NotificacoesState extends State<Notificacoes> {
  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _solicitacoes = [];
  bool _carregando = true;
  final Set<dynamic> _processando = {};

  bool get _souUsuario => widget.tipoConta == 'usuario';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final dados = _souUsuario
        ? await _apiService.buscarSolicitacoesPrestador(widget.identificador)
        : await _apiService.buscarSolicitacoesOng(widget.identificador);

    if (!mounted) return;

    final lista = dados.whereType<Map<String, dynamic>>().toList();
    setState(() {
      _solicitacoes = lista;
      _carregando = false;
    });

    // Marca as recém-carregadas como lidas pra zerar o badge do sino.
    _marcarTodasComoLidas(lista);
  }

  Future<void> _marcarTodasComoLidas(List<Map<String, dynamic>> lista) async {
    final naoLidas = lista.where((s) => !_paraBool(s['lida']));
    for (final s in naoLidas) {
      final cod = s['codSolicitacao'];
      if (cod == null) continue;
      if (_souUsuario) {
        await _apiService.marcarSolicitacaoLida(cod);
      } else {
        await _apiService.marcarSolicitacaoOngLida(cod);
      }
    }
    SolicitacaoSessaoService.instance.recarregar();
  }

  static bool _paraBool(dynamic valor) =>
      valor == true || valor == 1 || valor == '1';

  // ─── Aceita/recusa uma solicitação recebida ─────────────────
  Future<void> _responder(Map<String, dynamic> s, String novoStatus) async {
    final cod = s['codSolicitacao'];
    if (cod == null) return;

    setState(() => _processando.add(cod));

    final resultado = _souUsuario
        ? await _apiService.alterarSolicitacao(
            cod,
            statusS: novoStatus,
            statusE: s['statusExecucao']?.toString() ?? 'Não iniciado',
            pontos: s['pontos'] ?? 0,
          )
        : await _apiService.alterarSolicitacaoOng(
            cod,
            statusS: novoStatus,
            statusE: s['statusExecucao']?.toString() ?? 'Não iniciado',
            pontos: s['pontos'] ?? 0,
          );

    if (!mounted) return;

    setState(() {
      _processando.remove(cod);
      if (resultado['sucesso'] == true) {
        final index = _solicitacoes.indexWhere((item) => item['codSolicitacao'] == cod);
        if (index != -1) {
          _solicitacoes[index] = {..._solicitacoes[index], 'statusSolicitacao': novoStatus};
        }
      }
    });

    if (resultado['sucesso'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['erro']?.toString() ?? 'Não foi possível atualizar a solicitação.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ─── Abre (ou cria) a conversa com quem fez a solicitação ───
  Future<void> _enviarMensagem(Map<String, dynamic> s) async {
    final cpfSolicitador = s['cpfSolicitador']?.toString();
    final nomeSolicitador = s['nomeSolicitador']?.toString() ?? 'Conta';
    final fotoSolicitador = s['fotoSolicitador']?.toString();

    if (cpfSolicitador == null || cpfSolicitador.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o chat.')),
      );
      return;
    }

    final resultado = await _apiService.buscarOuCriarConversa(
      tipo1: widget.tipoConta,
      id1: widget.identificador,
      tipo2: 'usuario',
      id2: cpfSolicitador,
    );
    if (!mounted) return;

    final conversa = resultado['conversa'];
    if (resultado['sucesso'] != true || conversa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o chat.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversaChat(
          conversaId: int.parse(conversa['id'].toString()),
          meuTipo: widget.tipoConta,
          meuId: widget.identificador,
          nomeOutraConta: nomeSolicitador,
          fotoOutraConta: (fotoSolicitador != null && fotoSolicitador.isNotEmpty)
              ? '${ApiService.baseUrl}$fotoSolicitador'
              : null,
        ),
      ),
    );
  }

  String _dataFormatada(dynamic isoData) {
    if (isoData == null) return '-';
    final data = DateTime.tryParse(isoData.toString());
    if (data == null) return '-';
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  Color _corStatus(String status) {
    switch (status.toLowerCase()) {
      case 'aceita':
        return const Color(0xFF3A5A40);
      case 'recusada':
        return const Color(0xFFC1121F);
      case 'realizada':
      case 'concluída':
      case 'concluida':
        return const Color(0xFF1D3557);
      default:
        return const Color(0xFF9A7B24);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(child: _corpo()),
          ],
        ),
      ),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: _verde));
    }

    if (_solicitacoes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: _verdeMedio,
              ),
              const SizedBox(height: 10),
              Text(
                "Nenhuma solicitação ainda",
                style: GoogleFonts.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF344E41),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _souUsuario
                    ? "Solicitações de outras contas pelos seus serviços aparecem aqui."
                    : "Solicitações de voluntários pelas suas atividades aparecem aqui.",
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  color: const Color(0xFF6B705C),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _verde,
      onRefresh: _carregar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _solicitacoes.length,
        itemBuilder: (context, index) => _cardSolicitacao(_solicitacoes[index]),
      ),
    );
  }

  Widget _cardSolicitacao(Map<String, dynamic> s) {
    final cod = s['codSolicitacao'];
    final nome = s['nomeSolicitador']?.toString() ?? 'Conta';
    final servico = s['nomeServico']?.toString() ?? '';
    final status = s['statusSolicitacao']?.toString() ?? 'Pendente';
    final data = _dataFormatada(s['dataSolicitacao']);
    final pontos = s['pontos']?.toString();
    final foto = s['fotoSolicitador']?.toString();
    final pendente = status.toLowerCase() == 'pendente';
    final processando = _processando.contains(cod);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0DDD8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: (foto != null && foto.isNotEmpty)
                ? Image.network(
                    '${ApiService.baseUrl}$foto',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iniciaisAvatar(nome),
                  )
                : _iniciaisAvatar(nome),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2D3319),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _corStatus(status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _corStatus(status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (servico.isNotEmpty)
                  Text(
                    servico,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B705C),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      data,
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                    if (pontos != null && pontos != '0') ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.stars_rounded,
                        size: 13,
                        color: const Color(0xFF9A7B24),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$pontos pts',
                        style: GoogleFonts.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9A7B24),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                if (processando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _verde),
                    ),
                  )
                else
                  Row(
                    children: [
                      if (pendente) ...[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _responder(s, 'Recusada'),
                            child: Text(
                              'Recusar',
                              style: GoogleFonts.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _verde,
                              foregroundColor: _branco,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _responder(s, 'Aceita'),
                            child: Text(
                              'Aceitar',
                              style: GoogleFonts.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        onPressed: () => _enviarMensagem(s),
                        tooltip: 'Enviar mensagem',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: _verdeMedio,
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

  Widget _iniciaisAvatar(String nome) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: _bege,
      child: Text(
        nome.isNotEmpty ? nome[0].toUpperCase() : "?",
        style: GoogleFonts.quicksand(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: _verde,
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
            "Solicitações",
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
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const Login()),
                  (route) => false,
                );
              } else if (value == 'meu_perfil') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _souUsuario
                        ? PerfilUsuario(
                            cpf: widget.identificador,
                            nomeInicial: widget.nome,
                          )
                        : PerfilOng(
                            cnpj: widget.identificador,
                            nomeInicial: widget.nome,
                          ),
                  ),
                );
              } else if (value == 'quem_somos') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuemSomos(
                      nome: widget.nome,
                      cpf: widget.identificador,
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
                      "Meu Perfil",
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (_souUsuario)
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
              radius: 18,
              backgroundColor: _verdeMedio.withOpacity(0.5),
              child: const Icon(Icons.more_vert_rounded, color: _branco, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM NAV ───────────────────────────────────────────
  Widget _buildBottomNav() {
    final navItems = _souUsuario
        ? [
            _NavItemNotificacoes(
              icon: Icons.home_rounded,
              outlinedIcon: Icons.home_outlined,
              label: "Início",
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => InicialUsuario(
                    nome: widget.nome,
                    cpf: widget.identificador,
                  ),
                ),
              ),
            ),
            _NavItemNotificacoes(
              icon: Icons.work_rounded,
              outlinedIcon: Icons.work_outline_rounded,
              label: "Serviços",
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => Servicos(
                    nome: widget.nome,
                    cpf: widget.identificador,
                    initialNavIndex: 1,
                  ),
                ),
              ),
            ),
            _NavItemNotificacoes(
              icon: Icons.favorite_rounded,
              outlinedIcon: Icons.favorite_border_rounded,
              label: "ONGs",
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => Ongs(
                    nome: widget.nome,
                    cpf: widget.identificador,
                    initialNavIndex: 2,
                  ),
                ),
              ),
            ),
            _NavItemNotificacoes(
              icon: Icons.chat_bubble_rounded,
              outlinedIcon: Icons.chat_bubble_outline_rounded,
              label: "Chat",
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => Chat(
                    tipoConta: "usuario",
                    identificador: widget.identificador,
                    nome: widget.nome,
                  ),
                ),
              ),
            ),
          ]
        : [
            _NavItemNotificacoes(
              icon: Icons.home_rounded,
              outlinedIcon: Icons.home_outlined,
              label: "Início",
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => InicialOng(
                    nome: widget.nome,
                    cnpj: widget.identificador,
                  ),
                ),
              ),
            ),
            _NavItemNotificacoes(
              icon: Icons.volunteer_activism_rounded,
              outlinedIcon: Icons.volunteer_activism_outlined,
              label: "Atividades",
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ServicosOng(
                    nome: widget.nome,
                    cnpj: widget.identificador,
                  ),
                ),
              ),
            ),
            _NavItemNotificacoes(
              icon: Icons.assignment_turned_in_rounded,
              outlinedIcon: Icons.assignment_turned_in_outlined,
              label: "Solicitações",
              onTap: null,
            ),
            _NavItemNotificacoes(
              icon: Icons.chat_bubble_rounded,
              outlinedIcon: Icons.chat_bubble_outline_rounded,
              label: "Chat",
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => Chat(
                    tipoConta: "ong",
                    identificador: widget.identificador,
                    nome: widget.nome,
                  ),
                ),
              ),
            ),
          ];

    final indiceAtual = _souUsuario ? -1 : 2;

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
          currentIndex: indiceAtual < 0 ? 0 : indiceAtual,
          onTap: (index) {
            final item = navItems[index];
            if (item.onTap != null) item.onTap!();
          },
          backgroundColor: _branco,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedItemColor: indiceAtual < 0 ? const Color(0xFFADB5BD) : _verde,
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
            final isSelected = indiceAtual == i;
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

// ─── NAV ITEM AUXILIAR ────────────────────────────────────
class _NavItemNotificacoes {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final VoidCallback? onTap;

  _NavItemNotificacoes({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    this.onTap,
  });
}
