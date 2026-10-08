import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mutuo/services/api_service.dart';

class EsqueciSenha extends StatefulWidget {
  const EsqueciSenha({super.key});

  @override
  State<EsqueciSenha> createState() => _EsqueciSenhaState();
}

class _EsqueciSenhaState extends State<EsqueciSenha>
    with TickerProviderStateMixin {
  static const _verde = Color.fromARGB(255, 58, 90, 64);
  static const _creme = Color.fromARGB(255, 225, 220, 208);
  static const _verdeClaro = Color.fromARGB(255, 214, 228, 208);
  static const _vermelho = Color.fromARGB(255, 211, 47, 47);

  final ApiService _api = ApiService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarController = TextEditingController();
  final FocusNode _codigoFocus = FocusNode();

  late final AnimationController _cursorController;
  late final AnimationController _shakeController;

  Timer? _timerReenvio;

  // Estado do fluxo
  int _etapa = 1;
  bool _avancando = true;
  String _tipo = 'usuario';
  String _email = '';
  String _codigo = '';

  // Etapa 1
  bool _enviando = false;
  String? _erroEmail;

  // Etapa 2
  bool _verificando = false;
  bool _erroCodigo = false;
  String? _mensagemCodigo;
  int _caixasVerdes = 0;
  int _segundosReenvio = 0;
  bool _reenviando = false;

  // Etapa 3
  bool _ocultarSenha = true;
  bool _ocultarConfirmar = true;
  bool _redefinindo = false;
  String? _erroSenha;
  String? _erroConfirmar;

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
  }

  @override
  void dispose() {
    _timerReenvio?.cancel();
    _emailController.dispose();
    _codigoController.dispose();
    _senhaController.dispose();
    _confirmarController.dispose();
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

  bool _emailValido(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  void _irPara(int etapa) {
    if (etapa == _etapa) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _avancando = etapa > _etapa;
      _etapa = etapa;
    });
  }

  void _voltarEtapa() {
    if (_etapa == 1) {
      Navigator.pop(context);
      return;
    }
    if (_etapa == 2) _pararContador();
    _irPara(_etapa - 1);
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

  // ── Etapa 1: solicitar código ──

  Future<void> _enviarCodigo() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _erroEmail = 'Digite seu e-mail.');
      return;
    }
    if (!_emailValido(email)) {
      setState(() => _erroEmail = 'Digite um e-mail válido.');
      return;
    }

    setState(() {
      _erroEmail = null;
      _enviando = true;
    });

    final res = await _api.solicitarCodigoRecuperacao(email, _tipo);
    if (!mounted) return;
    setState(() => _enviando = false);

    if (res['sucesso'] == true) {
      _email = email;
      _limparCodigo();
      _mensagemCodigo = null;
      _iniciarContador();
      _irPara(2);
    } else {
      _mostrarErro(_mensagemDe(res, 'Não foi possível enviar o código.'));
    }
  }

  // ── Etapa 2: código ──

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
    if (valor.length == 6 && !_verificando) _verificarCodigo(valor);
  }

  Future<void> _verificarCodigo(String valor) async {
    setState(() => _verificando = true);

    final res = await _api.verificarCodigoRecuperacao(_email, _tipo, valor);
    if (!mounted) return;

    if (res['sucesso'] == true) {
      _codigo = valor;
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
    HapticFeedback.lightImpact();
    for (var i = 1; i <= 6; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() => _caixasVerdes = i);
    }
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    _pararContador();
    _irPara(3);
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
    final res = await _api.solicitarCodigoRecuperacao(_email, _tipo);
    if (!mounted) return;
    setState(() => _reenviando = false);

    if (res['sucesso'] == true) {
      _limparCodigo();
      setState(() => _mensagemCodigo = null);
      _iniciarContador();
      _codigoFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código reenviado'),
          backgroundColor: _verde,
        ),
      );
    } else {
      _mostrarErro(_mensagemDe(res, 'Não foi possível reenviar o código.'));
    }
  }

  void _trocarEmail() {
    _pararContador();
    _codigo = '';
    _limparCodigo();
    _mensagemCodigo = null;
    _irPara(1);
  }

  // ── Etapa 3: nova senha ──

  int _nivelSenha(String s) {
    if (s.isEmpty) return 0;
    if (s.length < 8) return 1;
    var variedade = 0;
    if (RegExp(r'[a-z]').hasMatch(s)) variedade++;
    if (RegExp(r'[A-Z]').hasMatch(s)) variedade++;
    if (RegExp(r'\d').hasMatch(s)) variedade++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(s)) variedade++;
    if (variedade >= 3 || (s.length >= 12 && variedade >= 2)) return 3;
    if (variedade >= 2) return 2;
    return 1;
  }

  Future<void> _redefinirSenha() async {
    final senha = _senhaController.text;
    final confirmar = _confirmarController.text;

    String? erroSenha;
    String? erroConfirmar;
    if (senha.length < 8) {
      erroSenha = 'A senha deve ter no mínimo 8 caracteres.';
    }
    if (confirmar.isEmpty) {
      erroConfirmar = 'Confirme a nova senha.';
    } else if (senha != confirmar) {
      erroConfirmar = 'As senhas não coincidem.';
    }
    setState(() {
      _erroSenha = erroSenha;
      _erroConfirmar = erroConfirmar;
    });
    if (erroSenha != null || erroConfirmar != null) return;

    setState(() => _redefinindo = true);
    final res = await _api.redefinirSenha(_email, _tipo, _codigo, senha);
    if (!mounted) return;
    setState(() => _redefinindo = false);

    if (res['sucesso'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _verde,
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('Senha redefinida! Faça login com sua nova senha'),
              ),
            ],
          ),
        ),
      );
      Navigator.pop(context);
      return;
    }

    final msg = _mensagemDe(res, 'Não foi possível redefinir a senha.');
    if (RegExp(r'c[óo]digo|tentativas', caseSensitive: false).hasMatch(msg)) {
      // Código expirou / foi invalidado no meio-tempo: volta pra etapa 2.
      _mostrarErro(msg);
      _codigo = '';
      _limparCodigo();
      _mensagemCodigo = msg;
      _liberarReenvio();
      _irPara(2);
    } else if (msg.toLowerCase().contains('senha')) {
      setState(() => _erroSenha = msg);
    } else {
      _mostrarErro(msg);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _etapa == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _voltarEtapa();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _voltarEtapa,
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
                        child: Column(
                          children: [
                            _indicadorProgresso(),
                            const SizedBox(height: 26),
                            _conteudoEtapas(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _indicadorProgresso() {
    Widget bolinha(int n) {
      final ativo = _etapa == n;
      final feito = _etapa > n;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        width: ativo ? 30 : 26,
        height: ativo ? 30 : 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (ativo || feito) ? _verde : Colors.white,
          border: Border.all(
            color: (ativo || feito) ? _verde : Colors.grey.shade400,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: feito
            ? const Icon(Icons.check, size: 15, color: Colors.white)
            : Text(
                '$n',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ativo ? Colors.white : Colors.grey.shade500,
                ),
              ),
      );
    }

    Widget linha(int depoisDe) {
      return Expanded(
        child: Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.centerLeft,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            widthFactor: _etapa > depoisDe ? 1 : 0,
            child: Container(
              decoration: BoxDecoration(
                color: _verde,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 200,
      child: Row(
        children: [bolinha(1), linha(1), bolinha(2), linha(2), bolinha(3)],
      ),
    );
  }

  Widget _conteudoEtapas() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (atual, anteriores) => Stack(
        alignment: Alignment.topCenter,
        children: [...anteriores, ?atual],
      ),
      transitionBuilder: (child, animation) {
        final entrando = child.key == ValueKey(_etapa);
        final dx = (_avancando ? 0.25 : -0.25) * (entrando ? 1 : -1);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(dx, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: switch (_etapa) {
        1 => KeyedSubtree(key: const ValueKey(1), child: _etapaEmail()),
        2 => KeyedSubtree(key: const ValueKey(2), child: _etapaCodigo()),
        _ => KeyedSubtree(key: const ValueKey(3), child: _etapaSenha()),
      },
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

  InputDecoration _decoracao(String label, {String? erro, Widget? sufixo}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _verde),
      errorText: erro,
      suffixIcon: sufixo,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _verde, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  Widget _botao(String texto, bool carregando, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _verde,
          disabledBackgroundColor: _verde.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: carregando ? null : onPressed,
        child: carregando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                texto,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
      ),
    );
  }

  // ── Etapa 1 ──

  Widget _etapaEmail() {
    return Column(
      children: [
        _titulo('Esqueceu sua senha?'),
        const SizedBox(height: 8),
        const Text(
          'Informe seu e-mail para receber um código.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'usuario',
                label: Text('Usuário'),
                icon: Icon(Icons.person),
              ),
              ButtonSegment(
                value: 'ong',
                label: Text('ONG'),
                icon: Icon(Icons.volunteer_activism),
              ),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) {
              if (s.isNotEmpty) setState(() => _tipo = s.first);
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? _verde
                    : Colors.white,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : _verde,
              ),
              side: const WidgetStatePropertyAll(BorderSide(color: _verde)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _enviarCodigo(),
          onChanged: (_) {
            if (_erroEmail != null) setState(() => _erroEmail = null);
          },
          decoration: _decoracao(
            _tipo == 'ong' ? 'E-mail da ONG' : 'Email',
            erro: _erroEmail,
          ),
        ),
        const SizedBox(height: 30),
        _botao('Enviar código', _enviando, _enviarCodigo),
      ],
    );
  }

  // ── Etapa 2 ──

  Widget _etapaCodigo() {
    final larguraDisponivel = MediaQuery.of(context).size.width - 60;
    final larguraCaixa = math.min(48.0, (larguraDisponivel - 5 * 8) / 6);
    final alturaCaixa = larguraCaixa * 58 / 48;

    return Column(
      children: [
        _titulo('Digite o código'),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: 'Enviamos um código de 6 dígitos para\n',
            children: [
              TextSpan(
                text: _mascararEmail(_email),
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
          onPressed: _trocarEmail,
          child: const Text('Trocar e-mail', style: TextStyle(color: _verde)),
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

  // ── Etapa 3 ──

  Widget _etapaSenha() {
    final nivel = _nivelSenha(_senhaController.text);
    const cores = [
      Colors.transparent,
      Colors.redAccent,
      Colors.orangeAccent,
      _verde,
    ];
    const rotulos = ['', 'Fraca', 'Média', 'Forte'];

    return Column(
      children: [
        _titulo('Crie uma nova senha'),
        const SizedBox(height: 8),
        const Text(
          'Escolha uma senha que você não usou antes.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _senhaController,
          obscureText: _ocultarSenha,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) => setState(() => _erroSenha = null),
          decoration: _decoracao(
            'Nova senha',
            erro: _erroSenha,
            sufixo: IconButton(
              icon: Icon(
                _ocultarSenha ? Icons.visibility_off : Icons.visibility,
                color: _verde,
              ),
              onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 1; i <= 3; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: nivel >= i ? cores[nivel] : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mínimo de 8 caracteres',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              rotulos[nivel],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cores[nivel],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmarController,
          obscureText: _ocultarConfirmar,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _redefinirSenha(),
          onChanged: (_) {
            if (_erroConfirmar != null) setState(() => _erroConfirmar = null);
          },
          decoration: _decoracao(
            'Confirmar nova senha',
            erro: _erroConfirmar,
            sufixo: IconButton(
              icon: Icon(
                _ocultarConfirmar ? Icons.visibility_off : Icons.visibility,
                color: _verde,
              ),
              onPressed: () =>
                  setState(() => _ocultarConfirmar = !_ocultarConfirmar),
            ),
          ),
        ),
        const SizedBox(height: 30),
        _botao('Redefinir senha', _redefinindo, _redefinirSenha),
      ],
    );
  }
}
