import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:mutuo/services/api_service.dart';

/// Bandeiras suportadas pra detecção automática a partir do número digitado.
enum BandeiraCartao { visa, mastercard, elo, amex, hipercard, desconhecida }

class CheckoutPremiumOng extends StatefulWidget {
  final String cnpj;
  final String nomeInicial;

  const CheckoutPremiumOng({
    super.key,
    required this.cnpj,
    this.nomeInicial = '',
  });

  @override
  State<CheckoutPremiumOng> createState() => _CheckoutPremiumOngState();
}

class _CheckoutPremiumOngState extends State<CheckoutPremiumOng> {
  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  final ApiService _api = ApiService();

  final _nomeCartaoCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _validadeCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();

  // ─── Máscaras de input ───
  final _mascaraNumero = MaskTextInputFormatter(
    mask: '#### #### #### ####',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _mascaraValidade = MaskTextInputFormatter(
    mask: '##/##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _mascaraCvv = MaskTextInputFormatter(
    mask: '####',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _mascaraCpf = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  bool _enviando = false;
  BandeiraCartao _bandeira = BandeiraCartao.desconhecida;

  @override
  void dispose() {
    _nomeCartaoCtrl.dispose();
    _numeroCtrl.dispose();
    _validadeCtrl.dispose();
    _cvvCtrl.dispose();
    _cpfCtrl.dispose();
    super.dispose();
  }

  // ─── Detecta a bandeira a partir dos dígitos já digitados (BIN) ───
  BandeiraCartao _detectarBandeira(String numeroComMascara) {
    final digitos = numeroComMascara.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.isEmpty) return BandeiraCartao.desconhecida;

    if (RegExp(r'^4').hasMatch(digitos)) {
      return BandeiraCartao.visa;
    }
    if (RegExp(
      r'^(5[1-5]|2(2[2-9][1-9]|[3-6][0-9]{2}|7[0-1][0-9]|720))',
    ).hasMatch(digitos)) {
      return BandeiraCartao.mastercard;
    }
    if (RegExp(r'^3[47]').hasMatch(digitos)) {
      return BandeiraCartao.amex;
    }
    if (RegExp(r'^(606282|3841)').hasMatch(digitos)) {
      return BandeiraCartao.hipercard;
    }
    if (RegExp(
      r'^(401178|401179|431274|438935|451416|457393|457631|457632|504175|50(67[0-6][0-9]|677[0-8])|5090\d{2}|627780|636297|636368|65003[1-3]|65003[5-9]|6500[4-5][0-9]|65040[5-9]|6504[1-3][0-9]|65048[5-9]|6504[9][0-9]|6505[0-3][0-9]|65054[0-8]|6505[5-9][0-9]|6506[0-7][0-9]|65070[0-7]|65072[0-7]|65090[1-9]|65091[0-9]|65092[0]|6516[5-7][0-9]|6550[0-1][0-9]|6550[2-5][0-9])',
    ).hasMatch(digitos)) {
      return BandeiraCartao.elo;
    }
    return BandeiraCartao.desconhecida;
  }

  String? get _bandeiraAsset {
    switch (_bandeira) {
      case BandeiraCartao.visa:
        return 'assets/bandeiras/visa.png';
      case BandeiraCartao.mastercard:
        return 'assets/bandeiras/mastercard.png';
      case BandeiraCartao.elo:
        return 'assets/bandeiras/elo.png';
      case BandeiraCartao.amex:
        return 'assets/bandeiras/amex.png';
      case BandeiraCartao.hipercard:
        return 'assets/bandeiras/hipercard.svg';
      case BandeiraCartao.desconhecida:
        return null;
    }
  }

  Future<void> _confirmarAssinatura() async {
    if (_nomeCartaoCtrl.text.trim().isEmpty ||
        _numeroCtrl.text.trim().isEmpty ||
        _validadeCtrl.text.trim().isEmpty ||
        _cvvCtrl.text.trim().isEmpty ||
        _cpfCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os dados de pagamento.')),
      );
      return;
    }

    setState(() => _enviando = true);
    final resultado = await _api.ativarPremiumOng(widget.cnpj);
    if (!mounted) return;
    setState(() => _enviando = false);

    if (resultado['sucesso'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assinatura confirmada! Bem-vindo ao Premium 🎉'),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado['erro']?.toString() ??
                'Não foi possível confirmar a assinatura.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _cardFormulario(),
                    const SizedBox(height: 18),
                    _cardResumo(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _branco,
              size: 18,
            ),
          ),
          Text(
            'Assinatura',
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _branco,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardFormulario() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assinar Premium para ONG',
            style: GoogleFonts.quicksand(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A2E1B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Preencha os dados de pagamento para concluir sua assinatura',
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: const Color(0xFF6B705C),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF0E4B0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFFB08900),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ambiente de simulação: nenhuma cobrança real será feita e nenhum dado de cartão será armazenado.',
                    style: GoogleFonts.quicksand(
                      fontSize: 11.5,
                      color: const Color(0xFF7A6300),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _cartaoVisual(),
          const SizedBox(height: 20),
          _campoLabel('Nome impresso no cartão'),
          _campoInput(
            controller: _nomeCartaoCtrl,
            hint: 'Ex.: MARIA S SILVA',
            capitalizacao: TextCapitalization.characters,
          ),
          const SizedBox(height: 14),
          _campoLabel('Número do cartão'),
          _campoInput(
            controller: _numeroCtrl,
            hint: '0000 0000 0000 0000',
            tipoNumerico: true,
            formatters: [_mascaraNumero],
            sufixo: _bandeiraAsset == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _iconeBandeira(_bandeira, tamanho: 28),
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _campoLabel('Validade'),
                    _campoInput(
                      controller: _validadeCtrl,
                      hint: 'MM/AA',
                      tipoNumerico: true,
                      formatters: [_mascaraValidade],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _campoLabel('CVV'),
                    _campoInput(
                      controller: _cvvCtrl,
                      hint: _bandeira == BandeiraCartao.amex ? '1234' : '123',
                      tipoNumerico: true,
                      formatters: [_mascaraCvv],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _campoLabel('CPF do titular'),
                    _campoInput(
                      controller: _cpfCtrl,
                      hint: '000.000.000-00',
                      tipoNumerico: true,
                      formatters: [_mascaraCpf],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                foregroundColor: _branco,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _enviando ? null : _confirmarAssinatura,
              icon: _enviando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _branco,
                      ),
                    )
                  : const Icon(Icons.lock_outline_rounded, size: 18),
              label: Text(
                _enviando
                    ? 'Confirmando...'
                    : 'Confirmar assinatura — R\$ 49,90/mês',
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

  /// Ícone da bandeira. SVG pro Hipercard, PNG pras demais.
  Widget _iconeBandeira(BandeiraCartao bandeira, {double tamanho = 32}) {
    final asset = _bandeiraAsset;
    if (asset == null) return const SizedBox.shrink();

    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        width: tamanho,
        height: tamanho * 0.64,
        fit: BoxFit.contain,
      );
    }
    return Image.asset(
      asset,
      width: tamanho,
      height: tamanho * 0.64,
      fit: BoxFit.contain,
    );
  }

  Widget _cartaoVisual() {
    return Container(
      width: double.infinity,
      height: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_verde, _verdeMedio],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 26,
                decoration: BoxDecoration(
                  color: _branco.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.memory_rounded,
                  size: 16,
                  color: _verde,
                ),
              ),
              // ─── Bandeira detectada aparece aqui, no canto do cartão ───
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _bandeiraAsset == null
                    ? const SizedBox(key: ValueKey('vazio'))
                    : Container(
                        key: ValueKey(_bandeira),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _branco.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _iconeBandeira(_bandeira, tamanho: 40),
                      ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            _numeroCtrl.text.isEmpty ? '•••• •••• •••• ••••' : _numeroCtrl.text,
            style: GoogleFonts.robotoMono(
              fontSize: 17,
              color: _branco,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _nomeCartaoCtrl.text.isEmpty
                    ? 'NOME NO CARTÃO'
                    : _nomeCartaoCtrl.text.toUpperCase(),
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _branco,
                ),
              ),
              Text(
                _validadeCtrl.text.isEmpty ? 'MM/AA' : _validadeCtrl.text,
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _branco,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _campoLabel(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: GoogleFonts.quicksand(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF344E41),
        ),
      ),
    );
  }

  Widget _campoInput({
    required TextEditingController controller,
    required String hint,
    bool tipoNumerico = false,
    List<TextInputFormatter>? formatters,
    TextCapitalization capitalizacao = TextCapitalization.none,
    Widget? sufixo,
  }) {
    return TextField(
      controller: controller,
      keyboardType: tipoNumerico ? TextInputType.number : TextInputType.text,
      textCapitalization: capitalizacao,
      inputFormatters: formatters,
      onChanged: (valor) {
        setState(() {
          // Atualiza a bandeira detectada sempre que o número do cartão muda.
          if (identical(controller, _numeroCtrl)) {
            _bandeira = _detectarBandeira(valor);
          }
        });
      },
      style: GoogleFonts.quicksand(
        fontSize: 13,
        color: const Color(0xFF344E41),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.quicksand(
          fontSize: 13,
          color: const Color(0xFFB0B0B0),
        ),
        filled: true,
        fillColor: const Color(0xFFF4F2ED),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: sufixo,
      ),
    );
  }

  Widget _cardResumo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo do pedido',
            style: GoogleFonts.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A2E1B),
            ),
          ),
          const SizedBox(height: 16),
          _linhaResumo('Plano', 'Premium ONG'),
          const SizedBox(height: 10),
          _linhaResumo('Cobrança', 'Mensal'),
          const SizedBox(height: 10),
          _linhaResumo('Renovação', 'Automática'),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEDEAE5)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total mensal',
                style: GoogleFonts.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A2E1B),
                ),
              ),
              Text(
                'R\$ 49,90',
                style: GoogleFonts.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _verde,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...const [
            'Pontos ilimitados',
            'Serviços ilimitados',
            'Visibilidade máxima na plataforma',
            'Prioridade nas solicitações',
            'Suporte prioritário 24 horas',
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: _verdeMedio,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.quicksand(
                        fontSize: 13,
                        color: const Color(0xFF344E41),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: Color(0xFF9AAB96),
                ),
                const SizedBox(width: 6),
                Text(
                  'Ambiente seguro de simulação',
                  style: GoogleFonts.quicksand(
                    fontSize: 11,
                    color: const Color(0xFF9AAB96),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaResumo(String label, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.quicksand(
            fontSize: 13,
            color: const Color(0xFF6B705C),
          ),
        ),
        Text(
          valor,
          style: GoogleFonts.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A2E1B),
          ),
        ),
      ],
    );
  }
}
