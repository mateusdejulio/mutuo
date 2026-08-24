import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/perfilOng.dart';

class PlanosOng extends StatelessWidget {
  final String cnpj;
  final String nomeInicial;

  const PlanosOng({super.key, required this.cnpj, this.nomeInicial = ''});

  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                        _cardPlano(
                      context: context,
                      titulo: 'Plano Gratuito',
                      preco: 'R\$ 0',
                      atual: true,
                      itens: const [
                        'Até 3 atividades ativas',
                        'Perfil público da ONG',
                        'Recebimento de solicitações',
                      ],
                    ),
                    const SizedBox(height: 16),
                    _cardPlano(
                      context: context,
                      titulo: 'Plano Premium',
                      preco: 'Sob consulta',
                      atual: false,
                      destaque: true,
                      itens: const [
                        'Atividades ilimitadas',
                        'Destaque na busca de voluntários',
                        'Selo de ONG premium no perfil',
                      ],
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
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _branco, size: 18),
          ),
          Text(
            'Nossos Planos',
            style: GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.w800, color: _branco),
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
                  MaterialPageRoute(builder: (_) => PerfilOng(cnpj: cnpj, nomeInicial: nomeInicial)),
                );
              }
            },
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'meu_perfil',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18, color: _verde),
                    const SizedBox(width: 8),
                    Text('Meu Perfil', style: GoogleFonts.quicksand(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 18, color: _verde),
                    const SizedBox(width: 8),
                    Text('Sair', style: GoogleFonts.quicksand(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: _verdeMedio.withOpacity(0.5), shape: BoxShape.circle),
              child: const Icon(Icons.person, color: _branco, size: 18),
            ),
          ),
        ],
      ),
    );
  }

    Widget _cardPlano({
    required BuildContext context,
    required String titulo,
    required String preco,
    required bool atual,
    required List<String> itens,
    bool destaque = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: destaque ? _verde : _branco,
        borderRadius: BorderRadius.circular(22),
        border: destaque ? null : Border.all(color: const Color(0xFFE0DDD8)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: GoogleFonts.quicksand(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: destaque ? _branco : const Color(0xFF1A2E1B),
                  ),
                ),
              ),
              if (atual)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _bege, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    'Plano atual',
                    style: GoogleFonts.quicksand(fontSize: 10, fontWeight: FontWeight.w800, color: _verde),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            preco,
            style: GoogleFonts.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: destaque ? _branco : _verde,
            ),
          ),
          const SizedBox(height: 16),
          ...itens.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: destaque ? _branco : _verdeMedio),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.quicksand(
                          fontSize: 13,
                          color: destaque ? _branco.withOpacity(0.9) : const Color(0xFF6B705C),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          if (!atual) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: destaque ? _branco : _verde,
                  foregroundColor: destaque ? _verde : _branco,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  // TODO: não existe rota de assinatura/pagamento no backend ainda —
                  // ligue aqui quando ela for criada.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Em breve: assinatura de planos')),
                  );
                },
                child: Text('Quero esse plano', style: GoogleFonts.quicksand(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}