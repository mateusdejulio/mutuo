import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/conversaChat.dart';
import 'package:mutuo/inicialOng.dart';
import 'package:mutuo/inicialUser.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/main.dart' show routeObserver;
import 'package:mutuo/models/conversa.dart';
import 'package:mutuo/models/mensagem.dart';
import 'package:mutuo/ongs.dart';
import 'package:mutuo/perfil.dart';
import 'package:mutuo/perfilOng.dart';
import 'package:mutuo/quem_somos.dart';
import 'package:mutuo/servicos.dart';
import 'package:mutuo/servicosOng.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:mutuo/services/auth_service.dart';
import 'package:mutuo/services/chat_socket_service.dart';
import 'package:mutuo/widgets/avatar_perfil.dart';
import 'package:mutuo/widgets/chat_badge_icon.dart';

// ─── TELA LISTA DE CONVERSAS ────────────────────────────────
class Chat extends StatefulWidget {
  final String tipoConta; // 'usuario' ou 'ong'
  final String identificador; // cpf ou cnpj
  final String nome;

  const Chat({
    super.key,
    required this.tipoConta,
    required this.identificador,
    required this.nome,
  });

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> with RouteAware {
  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  final ApiService _apiService = ApiService();
  final ChatSocketService _socketService = ChatSocketService.instance;
  List<Conversa> _conversas = [];
  bool _carregando = true;
  String? _fotoPropriaOng;
  final List<void Function()> _cancelarListeners = [];

  bool get _souUsuario => widget.tipoConta == 'usuario';

  @override
  void initState() {
    super.initState();
    _carregarConversas();
    if (!_souUsuario) _carregarFotoPropriaOng();
    _conectarSocket();
  }

  // Mantém a lista atualizada em tempo real (nova mensagem chegando ou sendo
  // enviada em qualquer conversa), sem precisar sair e voltar pra essa tela.
  // A conexão é idempotente/compartilhada com o resto do app (ChatSessaoService).
  void _conectarSocket() {
    _socketService.conectar(widget.tipoConta, widget.identificador);

    // mensagem:nova = mensagem recebida de outra conta -> conta como não lida.
    _cancelarListeners.add(
      _socketService.onMensagemNova(
        (mensagem) => _atualizarPreview(mensagem, incrementarNaoLidas: true),
      ),
    );
    // mensagem:enviada = ack da mensagem que EU mandei -> não é não lida.
    _cancelarListeners.add(
      _socketService.onMensagemEnviada(
        (mensagem) => _atualizarPreview(mensagem, incrementarNaoLidas: false),
      ),
    );
  }

  // Atualiza a prévia/ordem da conversa localmente. Se a conversa ainda não
  // estiver na lista (ex: primeira mensagem de uma conta nova), recarrega
  // do servidor pra pegar nome/foto de quem está do outro lado.
  void _atualizarPreview(Mensagem mensagem, {required bool incrementarNaoLidas}) {
    if (!mounted) return;

    final index = _conversas.indexWhere((c) => c.id == mensagem.conversaId);
    if (index == -1) {
      _carregarConversas();
      return;
    }

    setState(() {
      final atual = _conversas.removeAt(index);
      final atualizada = atual.copyWith(
        ultimaMensagem: mensagem.conteudo,
        ultimaMensagemEm: mensagem.enviadaEm,
        naoLidas: incrementarNaoLidas ? atual.naoLidas + 1 : atual.naoLidas,
      );
      _conversas.insert(0, atualizada);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    for (final cancelar in _cancelarListeners) {
      cancelar();
    }
    _cancelarListeners.clear();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Recarrega a lista sempre que voltamos pra essa tela (ex: saindo de uma conversa).
  @override
  void didPopNext() {
    _carregarConversas();
  }

  Future<void> _carregarConversas() async {
    final dados = await _apiService.buscarConversas(
      widget.tipoConta,
      widget.identificador,
    );
    if (!mounted) return;

    setState(() {
      _conversas = dados
          .whereType<Map<String, dynamic>>()
          .map((json) => Conversa.fromJson(json))
          .toList();
      _carregando = false;
    });
  }

  Future<void> _carregarFotoPropriaOng() async {
    final foto = await _apiService.buscarFotoPerfilOng(widget.identificador);
    if (!mounted) return;
    setState(() => _fotoPropriaOng = foto);
  }

  String get _inicialPropria =>
      widget.nome.isNotEmpty ? widget.nome[0].toUpperCase() : (_souUsuario ? "U" : "O");

  String _formatarHora(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _abrirConversa(Conversa conversa) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversaChat(
          conversaId: conversa.id,
          meuTipo: widget.tipoConta,
          meuId: widget.identificador,
          nomeOutraConta: conversa.nomeOutraConta ?? 'Conta',
          fotoOutraConta: conversa.fotoOutraConta != null
              ? '${ApiService.baseUrl}${conversa.fotoOutraConta}'
              : null,
        ),
      ),
    );
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

    if (_conversas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: _verdeMedio,
              ),
              const SizedBox(height: 10),
              Text(
                "Nenhuma conversa ainda",
                style: GoogleFonts.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF344E41),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Fale com ONGs e usuários pelos botões de contato nas telas de serviços.",
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
      onRefresh: _carregarConversas,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _conversas.length,
        itemBuilder: (context, index) => _itemConversa(_conversas[index]),
      ),
    );
  }

  Widget _itemConversa(Conversa conversa) {
    final foto = conversa.fotoOutraConta;
    final nome = conversa.nomeOutraConta ?? 'Conta';
    final temNaoLidas = conversa.naoLidas > 0;

    return GestureDetector(
      onTap: () => _abrirConversa(conversa),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _branco,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE0DDD8)),
        ),
        child: Row(
          children: [
            ClipOval(
              child: (foto != null && foto.isNotEmpty)
                  ? Image.network(
                      '${ApiService.baseUrl}$foto',
                      width: 48,
                      height: 48,
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
                      Text(
                        _formatarHora(conversa.ultimaMensagemEm),
                        style: GoogleFonts.quicksand(
                          fontSize: 11,
                          color: const Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversa.ultimaMensagem ?? 'Nenhuma mensagem ainda',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            fontWeight: temNaoLidas
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: temNaoLidas
                                ? const Color(0xFF344E41)
                                : const Color(0xFF6B705C),
                          ),
                        ),
                      ),
                      if (temNaoLidas) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _verde,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "${conversa.naoLidas}",
                            style: GoogleFonts.quicksand(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _branco,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iniciaisAvatar(String nome) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: _bege,
      child: Text(
        nome.isNotEmpty ? nome[0].toUpperCase() : "?",
        style: GoogleFonts.quicksand(
          fontSize: 18,
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
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      child: Row(
        children: [
          Text(
            "Chat",
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
            child: _avatarProprio(),
          ),
        ],
      ),
    );
  }

  Widget _avatarProprio() {
    if (_souUsuario) {
      return AvatarPerfil(
        cpf: widget.identificador,
        nome: widget.nome,
        radius: 20,
      );
    }

    final foto = _fotoPropriaOng;
    if (foto == null || foto.isEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: _bege,
        child: Text(
          _inicialPropria,
          style: GoogleFonts.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _verde,
          ),
        ),
      );
    }
    return ClipOval(
      child: Image.network(
        '${ApiService.baseUrl}$foto',
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: 20,
          backgroundColor: _bege,
          child: Text(
            _inicialPropria,
            style: GoogleFonts.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _verde,
            ),
          ),
        ),
      ),
    );
  }

  // ─── BOTTOM NAV ───────────────────────────────────────────
  Widget _buildBottomNav() {
    final navItems = _souUsuario
        ? [
            _NavItemChat(
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
            _NavItemChat(
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
            _NavItemChat(
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
            _NavItemChat(
              icon: Icons.chat_bubble_rounded,
              outlinedIcon: Icons.chat_bubble_outline_rounded,
              label: "Chat",
              onTap: null,
            ),
          ]
        : [
            _NavItemChat(
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
            _NavItemChat(
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
            _NavItemChat(
              icon: Icons.assignment_turned_in_rounded,
              outlinedIcon: Icons.assignment_turned_in_outlined,
              label: "Solicitações",
              onTap: null,
            ),
            _NavItemChat(
              icon: Icons.chat_bubble_rounded,
              outlinedIcon: Icons.chat_bubble_outline_rounded,
              label: "Chat",
              onTap: null,
            ),
          ];

    const indiceAtual = 3;

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
          currentIndex: indiceAtual,
          onTap: (index) {
            final item = navItems[index];
            if (item.onTap != null) item.onTap!();
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
class _NavItemChat {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final VoidCallback? onTap;

  _NavItemChat({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    this.onTap,
  });
}
