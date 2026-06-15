import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/inicialUser.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/ongs.dart';
import 'package:mutuo/servicos.dart';

class QuemSomos extends StatefulWidget {
  final String nome;
  const QuemSomos({super.key, required this.nome});

  @override
  State<QuemSomos> createState() => _QuemSomosState();
}

class _QuemSomosState extends State<QuemSomos> {
  int _bottomNavIndex = 0;

  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  String get _inicial =>
      widget.nome.isNotEmpty ? widget.nome[0].toUpperCase() : "U";

  final List<Map<String, String>> _fundadores = [
    {
      'nome': 'Elis Meneghin',
      'cargo': 'FUNDADORA',
      'imagem': 'assets/images/elis.png',
    },
    {
      'nome': 'Manuela Azevedo',
      'cargo': 'FUNDADORA',
      'imagem': 'assets/images/manuela.png',
    },
    {
      'nome': 'Mateus De Julio',
      'cargo': 'FUNDADOR',
      'imagem': 'assets/images/deJulio.png',
    },
  ];

  void _onNavTap(int index) {
    if (index == _bottomNavIndex) return;
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, __, ___) => InicialUsuario(nome: widget.nome),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, __, ___) =>
              Servicos(nome: widget.nome, initialNavIndex: 1),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, __, ___) =>
              Ongs(nome: widget.nome, initialNavIndex: 2),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Quem somos",
                      style: GoogleFonts.quicksand(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _verde,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "O Mútuo nasceu da vontade de três estudantes — ",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: const Color(0xFF344E41),
                        height: 1.6,
                      ),
                    ),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.quicksand(
                          fontSize: 14,
                          color: const Color(0xFF344E41),
                          height: 1.6,
                        ),
                        children: [
                          TextSpan(
                            text:
                                "Elis Meneghin, Manuela Azevedo e Mateus De Julio",
                            style: GoogleFonts.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF344E41),
                              height: 1.6,
                            ),
                          ),
                          const TextSpan(
                            text:
                                " — de criar uma forma simples e acessível de conectar pessoas dispostas a ajudar com ONGs que precisam de apoio. Durante nossos estudos e vivências, percebemos que muitas pessoas querem fazer o bem, mas não sabem por onde começar, e que diversas instituições enfrentam dificuldades para divulgar suas causas.",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Foi assim que surgiu o Mútuo — uma plataforma colaborativa que promove a troca de serviços e experiências solidárias, fortalecendo o vínculo entre indivíduos e organizações. Aqui, cada ajuda gera impacto real, e cada ação é uma oportunidade de aprender e transformar o mundo. Nosso propósito é facilitar o voluntariado e incentivar a solidariedade como prática cotidiana. Acreditamos que ajudar pode ser simples, recompensador e transformador.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: const Color(0xFF344E41),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      "Nossos Fundadores",
                      style: GoogleFonts.quicksand(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _verde,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _fundadores
                          .map((f) => _fundadorCard(f))
                          .toList(),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fundadorCard(Map<String, String> f) {
    return Column(
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: _bege,
          backgroundImage: AssetImage(f['imagem']!),
          onBackgroundImageError: (_, __) {},
          child: null,
        ),
        const SizedBox(height: 10),
        Text(
          f['nome']!,
          textAlign: TextAlign.center,
          style: GoogleFonts.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF344E41),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          f['cargo']!,
          style: GoogleFonts.quicksand(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B705C),
            letterSpacing: 1.0,
          ),
        ),
      ],
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: _branco.withOpacity(0.95),
            ),
            splashRadius: 20,
          ),
          const SizedBox(width: 6),
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const Login()),
                );
              }
            },
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            itemBuilder: (_) => [
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
              radius: 20,
              backgroundColor: _bege,
              child: Text(
                _inicial,
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _verde,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final List<_NavItem> navItems = [
      _NavItem(
        icon: Icons.home_rounded,
        outlinedIcon: Icons.home_outlined,
        label: "Início",
      ),
      _NavItem(
        icon: Icons.work_rounded,
        outlinedIcon: Icons.work_outline_rounded,
        label: "Serviços",
      ),
      _NavItem(
        icon: Icons.favorite_rounded,
        outlinedIcon: Icons.favorite_border_rounded,
        label: "ONGs",
      ),
      _NavItem(
        icon: Icons.chat_bubble_rounded,
        outlinedIcon: Icons.chat_bubble_outline_rounded,
        label: "Chat",
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
          onTap: _onNavTap,
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
}

class _NavItem {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
  });
}
