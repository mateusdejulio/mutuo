import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/perfilOng.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:mutuo/checkoutPremiumOng.dart';

class PlanosOng extends StatefulWidget {
  final String cnpj;
  final String nomeInicial;

  const PlanosOng({super.key, required this.cnpj, this.nomeInicial = ''});

  @override
  State<PlanosOng> createState() => _PlanosOngState();
}

class _PlanosOngState extends State<PlanosOng> {
  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  final ApiService _api = ApiService();

  Map<String, dynamic>? _ong;
  bool _carregando = true;

  bool get _isPremium => _ong?['premium'] == 1;

  @override
  void initState() {
    super.initState();
    _carregarOng();
  }

    Future<void> _carregarOng() async {
    setState(() => _carregando = true);
    final dados = await _api.buscarOngPorCnpj(widget.cnpj);
    if (!mounted) return;
    setState(() {
      _ong = dados;
      _carregando = false;
    });
  }

  Future<void> _confirmarCancelamento() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancelar assinatura',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Tem certeza que deseja cancelar o plano Premium da ONG? Vocês voltam pro plano gratuito (até 5 serviços ativos) imediatamente.',
          style: GoogleFonts.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Voltar',
              style: GoogleFonts.quicksand(color: const Color(0xFF6B705C)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Cancelar assinatura',
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

    setState(() => _carregando = true);
    final resultado = await _api.cancelarPremiumOng(widget.cnpj);
    if (!mounted) return;

    if (resultado['sucesso'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assinatura cancelada. Vocês voltaram ao plano gratuito.'),
        ),
      );
      await _carregarOng();
    } else {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado['erro']?.toString() ??
                'Não foi possível cancelar a assinatura.',
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
              const SizedBox(height: 24),
              if (_carregando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: _verde),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Escolha o melhor plano\npara sua ONG',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.quicksand(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A2E1B),
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Potencialize o impacto social da sua instituição',
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
                      const SizedBox(height: 30),
                      _cardPlano(
                        icone: Icons.auto_awesome_rounded,
                        titulo: 'Gratuito',
                        preco: 'R\$ 0,00',
                        atual: !_isPremium,
                        itens: const [
                          '1500 pontos mensais',
                          'Até 5 serviços ativos',
                          'Suporte básico',
                          'Visualização padrão',
                        ],
                      ),
                      const SizedBox(height: 28),
                      _cardPlano(
                        icone: Icons.bolt_rounded,
                        titulo: 'Premium',
                        preco: 'R\$ 49,90',
                        atual: _isPremium,
                        destaque: true,
                        recomendado: true,
                        itens: const [
                          'Pontos ilimitados',
                          'Visibilidade máxima na plataforma',
                          'Serviços ilimitados',
                          'Suporte prioritário 24h',
                        ],
                                                onAssinar: () async {
                          final resultado = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CheckoutPremiumOng(
                                cnpj: widget.cnpj,
                                nomeInicial: widget.nomeInicial,
                              ),
                            ),
                          );
                          if (resultado == true) _carregarOng();
                        },
                        permiteCancelamento: true,
                        onCancelar: _confirmarCancelamento,
                      ),
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
            'Nossos Planos',
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _branco,
            ),
          ),
          const Spacer(),
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
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _verdeMedio.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: _branco, size: 18),
            ),
          ),
        ],
      ),
    );
  }

    Widget _cardPlano({
    required IconData icone,
    required String titulo,
    required String preco,
    required bool atual,
    required List<String> itens,
    bool destaque = false,
    bool recomendado = false,
    bool permiteCancelamento = false,
    VoidCallback? onAssinar,
    VoidCallback? onCancelar,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: recomendado ? 14 : 0),
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          decoration: BoxDecoration(
            color: destaque ? _branco : _bege,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: destaque ? _verde : Colors.transparent,
              width: destaque ? 1.6 : 0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icone, size: 34, color: _verde),
              const SizedBox(height: 12),
              Text(
                titulo,
                style: GoogleFonts.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A2E1B),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    preco,
                    style: GoogleFonts.quicksand(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: _verde,
                    ),
                  ),
                  Text(
                    '/mês',
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9AAB96),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...itens.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color: _verdeMedio,
                      ),
                      const SizedBox(width: 10),
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
                            const SizedBox(height: 8),
              if (atual) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _verde.withOpacity(0.4),
                        width: 1.4,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledForegroundColor: _verde,
                    ),
                    child: Text(
                      'PLANO ATUAL',
                      style: GoogleFonts.quicksand(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                if (permiteCancelamento) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onCancelar,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                        'Cancelar assinatura',
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ] else if (destaque)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _verde,
                      foregroundColor: _branco,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onAssinar,
                    child: Text(
                      'ASSINAR AGORA',
                      style: GoogleFonts.quicksand(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (recomendado)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _verde,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'MAIS RECOMENDADO',
                  style: GoogleFonts.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _branco,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
