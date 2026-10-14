import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/services/api_service.dart';

// Tela de confirmação de e-mail depois do cadastro (ou de um login com
// conta ainda não confirmada). Mesma etapa do código de esqueci_senha.dart.
class ConfirmarEmail extends StatefulWidget {
  const ConfirmarEmail({super.key, required this.email, required this.tipo});

  final String email;
  final String tipo; // 'usuario' ou 'ong'

  @override
  State<ConfirmarEmail> createState() => _ConfirmarEmailState();
}

class _ConfirmarEmailState extends State<ConfirmarEmail>
    with TickerProviderStateMixin {
  static const _verde = Color.fromARGB(255, 58, 90, 64);
  static const _creme = Color.fromARGB(255, 225, 220, 208);
  static const _verdeClaro = Color.fromARGB(255, 214, 228, 208);
  static const _vermelho = Color.fromARGB(255, 211, 47, 47);

  final ApiService _api = ApiService();

  final TextEditingController _codigoController = TextEditingController();
  final FocusNode _codigoFocus = FocusNode();

  late final AnimationController _cursorController;
  late final AnimationController _shakeController;

  Timer? _timerReenvio;

  bool _verificando = false;
  bool _erroCodigo = false;
  String? _mensagemCodigo;
  int _caixasVerdes = 0;
  int _segundosReenvio = 0;
  bool _reenviando = false;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _codigoFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _iniciarContador();
  }

  @override
  void dispose() {
    _timerReenvio?.cancel();
    _codigoController.dispose();
    _codigoFocus.dispose();
    _cursorController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Utilitários ──

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.redAccent),
    );
  }

  String _mensagemDe(Map<String, dynamic> res, String padrao) {
    final msg = res['mensagem']?.toString() ?? '';
    return msg.isNotEmpty ? msg : padrao;
  }

  String _mascararEmail(String? email) {
    if (email == null || email.isEmpty || !email.contains('@')) {
      return email ?? '';
    }
    final partes = email.split('@');
    final usuario = partes.first;
    final dominio = partes.sublist(1).join('@');
    final inicial = usuario.isNotEmpty ? usuario[0] : '';
    return '$inicial****@$dominio';
  }

  // ── Reenvio ──

  void _iniciarContador() {
    _timerReenvio?.cancel();
    setState(() => _segundosReenvio = 60);
    _timerReenvio = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _segundosReenvio--);
      if (_segundosReenvio <= 0) timer.cancel();
    });
  }

  void _pararContador() {
    _timerReenvio?.cancel();
    _timerReenvio = null;
  }

  void _liberarReenvio() {
    _pararContador();
    setState(() => _segundosReenvio = 0);
  }

  String get _textoContador {
    final m = _segundosReenvio ~/ 60;
    final s = (_segundosReenvio % 60).toString().padLeft(2, '0');
    return 'Reenviar código em $m:$s';
  }

  // ── Código ──

  void _limparCodigo() {
    _codigoController.clear();
    setState(() {
      _erroCodigo = false;
      _caixasVerdes = 0;
      _verificando = false;
    });
  }

  void _aoDigitarCodigo(String valor) {
    setState(() {
      if (_erroCodigo) _erroCodigo = false;
      if (_mensagemCodigo != null) _mensagemCodigo = null;
    });
    if (valor.length == 6 && !_verificando) _confirmarCodigo(valor);
  }

  Future<void> _confirmarCodigo(String valor) async {
    setState(() => _verificando = true);

    final res = await _api.confirmarEmail(widget.email, widget.tipo, valor);
    if (!mounted) return;

    if (res['sucesso'] == true) {
      await _animarCodigoCerto();
      return;
    }

    // Erro de conexão (sem resposta da API sobre o código)
    final msg = _mensagemDe(res, 'Código incorreto.');
    if (msg.startsWith('Servidor iniciando')) {
      setState(() => _verificando = false);
      _mostrarErro(msg);
      return;
    }

    await _animarCodigoErrado(res, msg);
  }

  Future<void> _animarCodigoCerto() async {
    setState(() => _verificando = false);
    _pararContador();
    HapticFeedback.lightImpact();
    for (var i = 1; i <= 6; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() => _caixasVerdes = i);
    }
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('E-mail confirmado! Agora é só entrar.')),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const Login()),
      (route) => false,
    );
  }

  Future<void> _animarCodigoErrado(Map<String, dynamic> res, String msg) async {
    final restantes = res['tentativasRestantes'];
    var texto = msg;
    if (restantes is num && restantes > 0) {
      texto += restantes == 1
          ? ' 1 tentativa restante.'
          : ' $restantes tentativas restantes.';
    }

    setState(() {
      _verificando = false;
      _erroCodigo = true;
    });
    HapticFeedback.mediumImpact();

    // Código invalidado (tentativas esgotadas ou expirado): reenvio liberado na hora.
    if (restantes is! num || restantes <= 0) _liberarReenvio();

    await _shakeController.forward(from: 0);
    if (!mounted) return;

    _codigoController.clear();
    setState(() {
      _erroCodigo = false;
      _mensagemCodigo = texto;
    });
    _codigoFocus.requestFocus();
  }

  Future<void> _reenviarCodigo() async {
    setState(() => _reenviando = true);
    final res = await _api.reenviarConfirmacao(widget.email, widget.tipo);
    if (!mounted) return;
    setState(() => _reenviando = false);

    if (res['sucesso'] == true) {
      _limparCodigo();
      setState(() => _mensagemCodigo = null);
      _iniciarContador();
      _codigoFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mensagemDe(res, 'Código reenviado')),
          backgroundColor: _verde,
        ),
      );
    } else {
      _mostrarErro(_mensagemDe(res, 'Não foi possível reenviar o código.'));
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/fundo.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  Transform.translate(
                    offset: const Offset(0, 40),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _creme,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          "assets/images/logo.png",
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(30, 70, 30, 30),
                      decoration: const BoxDecoration(
                        color: _creme,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(175),
                          topRight: Radius.circular(175),
                        ),
                      ),
                      child: _etapaCodigo(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titulo(String texto) => Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _verde,
        ),
      );

  Widget _etapaCodigo() {
    final larguraDisponivel = MediaQuery.of(context).size.width - 60;
    final larguraCaixa = math.min(48.0, (larguraDisponivel - 5 * 8) / 6);
    final alturaCaixa = larguraCaixa * 58 / 48;

    return Column(
      children: [
        _titulo('Confirme seu e-mail'),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: 'Enviamos um código de 6 dígitos para\n',
            children: [
              TextSpan(
                text: '${_mascararEmail(widget.email)}.',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _verde,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 26),
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final t = _shakeController.value;
            final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _verificando ? 0.5 : 1,
            child: SizedBox(
              height: alturaCaixa + 12,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _codigoController,
                    builder: (context, valor, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 6; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          _caixaDigito(i, valor.text, larguraCaixa, alturaCaixa),
                        ],
                      ],
                    ),
                  ),
                  // Campo real, invisível por cima das caixas: recebe toque,
                  // colar e preenchimento automático do código.
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _codigoController,
                        focusNode: _codigoFocus,
                        autofocus: true,
                        readOnly: _verificando || _caixasVerdes > 0,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        autofillHints: const [AutofillHints.oneTimeCode],
                        showCursor: false,
                        onChanged: _aoDigitarCodigo,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: Center(
            child: _verificando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: _verde,
                      strokeWidth: 2.5,
                    ),
                  )
                : _caixasVerdes == 6
                    ? const Icon(Icons.check_circle, color: _verde, size: 26)
                    : _mensagemCodigo != null
                        ? Text(
                            _mensagemCodigo!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _vermelho,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 4),
        _segundosReenvio > 0
            ? Text(
                _textoContador,
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              )
            : _reenviando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: _verde,
                      strokeWidth: 2,
                    ),
                  )
                : TextButton.icon(
                    onPressed: _reenviarCodigo,
                    icon: const Icon(Icons.refresh, color: _verde, size: 18),
                    label: const Text(
                      'Reenviar código',
                      style: TextStyle(
                        color: _verde,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const Login()),
            (route) => false,
          ),
          child: const Text(
            'Voltar para o login',
            style: TextStyle(color: _verde),
          ),
        ),
      ],
    );
  }

  Widget _caixaDigito(int i, String texto, double largura, double altura) {
    final digito = i < texto.length ? texto[i] : '';
    final preenchida = digito.isNotEmpty;
    final verde = i < _caixasVerdes;
    final atual = _codigoFocus.hasFocus &&
        !_verificando &&
        _caixasVerdes == 0 &&
        i == math.min(texto.length, 5) &&
        !(texto.length == 6);

    Color corBorda;
    double larguraBorda;
    if (_erroCodigo) {
      corBorda = _vermelho;
      larguraBorda = 2;
    } else if (verde || atual) {
      corBorda = _verde;
      larguraBorda = 2;
    } else {
      corBorda = preenchida ? _verde.withValues(alpha: 0.5) : Colors.grey.shade400;
      larguraBorda = 1.5;
    }

    final Color fundo = verde
        ? _verde
        : _erroCodigo
            ? const Color.fromARGB(255, 251, 233, 233)
            : preenchida
                ? _verdeClaro
                : Colors.white;

    final caixa = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: largura,
      height: altura,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: corBorda, width: larguraBorda),
        boxShadow: atual
            ? [
                BoxShadow(
                  color: _verde.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: verde
          ? const Icon(Icons.check, color: Colors.white, size: 22)
          : preenchida
              ? Text(
                  digito,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: _erroCodigo ? _vermelho : _verde,
                  ),
                )
              : atual
                  ? FadeTransition(
                      opacity: _cursorController,
                      child: Container(width: 2, height: 26, color: _verde),
                    )
                  : null,
    );

    if (!preenchida) return caixa;

    // "Pop" sutil quando o dígito aparece.
    return TweenAnimationBuilder<double>(
      key: ValueKey('caixa-$i-$digito'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      builder: (context, t, child) => Transform.scale(
        scale: 1 + 0.08 * math.sin(t * math.pi),
        child: child,
      ),
      child: caixa,
    );
  }
}
