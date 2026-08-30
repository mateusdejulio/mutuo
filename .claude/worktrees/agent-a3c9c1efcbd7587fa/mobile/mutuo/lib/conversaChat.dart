import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/models/mensagem.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:mutuo/services/chat_sessao_service.dart';
import 'package:mutuo/services/chat_socket_service.dart';

// ─── TELA DE UMA CONVERSA ───────────────────────────────────
class ConversaChat extends StatefulWidget {
  final int conversaId;
  final String meuTipo;
  final String meuId;
  final String nomeOutraConta;
  final String? fotoOutraConta;

  const ConversaChat({
    super.key,
    required this.conversaId,
    required this.meuTipo,
    required this.meuId,
    required this.nomeOutraConta,
    this.fotoOutraConta,
  });

  @override
  State<ConversaChat> createState() => _ConversaChatState();
}

class _ConversaChatState extends State<ConversaChat> {
  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  final ApiService _apiService = ApiService();
  final ChatSocketService _socketService = ChatSocketService.instance;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Mensagem> _mensagens = [];
  bool _carregando = true;
  int _tempIdCounter = -1;
  final List<int> _pendentesTempIds = [];
  final List<void Function()> _cancelarListeners = [];

  @override
  void initState() {
    super.initState();
    // Enquanto esta conversa está na frente, ela não deve gerar notificação.
    ChatSessaoService.instance.definirConversaAberta(widget.conversaId);
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    final dados = await _apiService.buscarMensagens(
      widget.conversaId,
      meuTipo: widget.meuTipo,
      meuId: widget.meuId,
    );
    if (!mounted) return;

    setState(() {
      _mensagens = dados
          .whereType<Map<String, dynamic>>()
          .map((json) => Mensagem.fromJson(json))
          .toList();
      _carregando = false;
    });

    _conectarSocket();
    _marcarComoLida();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _conectarSocket() {
    // A conexão é única por sessão (ChatSessaoService); conectar aqui é
    // idempotente e cobre o caso de abrir a conversa direto de outra tela.
    _socketService.conectar(widget.meuTipo, widget.meuId);

    _cancelarListeners.add(_socketService.onMensagemNova((mensagem) {
      if (!mounted || mensagem.conversaId != widget.conversaId) return;
      setState(() => _mensagens.add(mensagem));
      _marcarComoLida();
      _scrollToBottom();
    }));

    _cancelarListeners.add(_socketService.onMensagemEnviada((mensagemReal) {
      if (!mounted || mensagemReal.conversaId != widget.conversaId) return;
      setState(() {
        if (_pendentesTempIds.isNotEmpty) {
          final tempId = _pendentesTempIds.removeAt(0);
          final index = _mensagens.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            _mensagens[index] = mensagemReal;
            return;
          }
        }
        _mensagens.add(mensagemReal);
      });
    }));

    // A outra conta abriu/leu a conversa: minhas mensagens viram "visto".
    _cancelarListeners.add(_socketService.onConversaLida((conversaId) {
      if (!mounted || conversaId != widget.conversaId) return;
      setState(() {
        _mensagens = _mensagens
            .map(
              (m) => (!m.lida && m.ehMinha(widget.meuTipo, widget.meuId))
                  ? m.copyWith(lida: true)
                  : m,
            )
            .toList();
      });
    }));
  }

  void _marcarComoLida() {
    _socketService.marcarComoLida(widget.conversaId, widget.meuTipo, widget.meuId);
    ChatSessaoService.instance.marcarConversaLidaLocal(widget.conversaId);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _enviar() {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;

    final tempId = _tempIdCounter--;
    final otimista = Mensagem(
      id: tempId,
      conversaId: widget.conversaId,
      tipoRemetente: widget.meuTipo,
      idRemetente: widget.meuId,
      conteudo: texto,
      enviadaEm: DateTime.now(),
    );

    setState(() {
      _mensagens.add(otimista);
      _pendentesTempIds.add(tempId);
    });
    _controller.clear();

    _socketService.enviarMensagem(
      widget.conversaId,
      widget.meuTipo,
      widget.meuId,
      texto,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    // Só remove os listeners desta tela: a conexão segue viva pela sessão.
    for (final cancelar in _cancelarListeners) {
      cancelar();
    }
    _cancelarListeners.clear();
    ChatSessaoService.instance.definirConversaAberta(null);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _inicialOutraConta => widget.nomeOutraConta.isNotEmpty
      ? widget.nomeOutraConta[0].toUpperCase()
      : "?";

  String _formatarHora(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: _carregando
                  ? const Center(
                      child: CircularProgressIndicator(color: _verde),
                    )
                  : _mensagens.isEmpty
                  ? _estadoVazio()
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _mensagens.length,
                      itemBuilder: (context, index) {
                        final mensagem =
                            _mensagens[_mensagens.length - 1 - index];
                        return _bolha(mensagem);
                      },
                    ),
            ),
            _campoEnvio(),
          ],
        ),
      ),
    );
  }

  // ─── HEADER (sem popup de perfil, só voltar) ───────────────
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
      padding: const EdgeInsets.fromLTRB(12, 12, 22, 20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: _branco),
          ),
          _avatarOutraConta(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.nomeOutraConta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.quicksand(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _branco,
              ),
            ),
          ),
          IconButton(
            onPressed: _confirmarLimparConversa,
            icon: const Icon(Icons.delete_outline_rounded, color: _branco),
            tooltip: 'Limpar conversa',
          ),
        ],
      ),
    );
  }

  // ─── Confirmação + chamada da API pra limpar a conversa ───
  Future<void> _confirmarLimparConversa() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Limpar conversa',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'As mensagens vão desaparecer só do seu lado. A outra conta continua vendo o histórico normalmente.',
          style: GoogleFonts.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.quicksand(color: _verdeMedio)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Limpar',
              style: GoogleFonts.quicksand(color: Colors.redAccent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) return;

    final resultado = await _apiService.limparConversa(
      widget.conversaId,
      meuTipo: widget.meuTipo,
      meuId: widget.meuId,
    );

    if (!mounted) return;

    if (resultado['sucesso'] == true) {
      setState(() => _mensagens = []);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['erro'] ?? 'Não foi possível limpar a conversa.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _avatarOutraConta() {
    final foto = widget.fotoOutraConta;
    if (foto == null || foto.isEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: _bege,
        child: Text(
          _inicialOutraConta,
          style: GoogleFonts.quicksand(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _verde,
          ),
        ),
      );
    }
    return ClipOval(
      child: Image.network(
        foto,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: 20,
          backgroundColor: _bege,
          child: Text(
            _inicialOutraConta,
            style: GoogleFonts.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _verde,
            ),
          ),
        ),
      ),
    );
  }

  Widget _estadoVazio() {
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
              "Envie a primeira mensagem para ${widget.nomeOutraConta}",
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

  // ─── BOLHA DE MENSAGEM ──────────────────────────────────────
  Widget _bolha(Mensagem mensagem) {
    final ehMinha = mensagem.ehMinha(widget.meuTipo, widget.meuId);

    return Align(
      alignment: ehMinha ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ehMinha ? _verde : _branco,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(ehMinha ? 16 : 4),
            bottomRight: Radius.circular(ehMinha ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mensagem.conteudo,
              style: GoogleFonts.quicksand(
                fontSize: 14,
                color: ehMinha ? _branco : const Color(0xFF2D3319),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatarHora(mensagem.enviadaEm),
                  style: GoogleFonts.quicksand(
                    fontSize: 10,
                    color: ehMinha ? _branco.withOpacity(0.7) : const Color(0xFF9E9E9E),
                  ),
                ),
                if (ehMinha) ...[
                  const SizedBox(width: 4),
                  _statusEnvio(mensagem),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── STATUS DE ENVIO (só nas minhas mensagens) ─────────────
  // Relógio = ainda enviando (id temporário/otimista); check simples =
  // entregue mas a outra conta ainda não abriu a conversa; check duplo
  // colorido = "visto" (a outra conta já marcou a conversa como lida).
  Widget _statusEnvio(Mensagem mensagem) {
    if (mensagem.id < 0) {
      return Icon(
        Icons.access_time_rounded,
        size: 12,
        color: _branco.withOpacity(0.7),
      );
    }
    if (mensagem.lida) {
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: Color(0xFF8ECAE6),
      );
    }
    return Icon(Icons.done_rounded, size: 14, color: _branco.withOpacity(0.7));
  }

  // ─── CAMPO DE ENVIO ─────────────────────────────────────────
  Widget _campoEnvio() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: _branco,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _fundo,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _enviar(),
                  style: GoogleFonts.quicksand(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Digite uma mensagem...",
                    hintStyle: GoogleFonts.quicksand(
                      fontSize: 14,
                      color: const Color(0xFF9E9E9E),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _enviar,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: _verde,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: _branco,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
