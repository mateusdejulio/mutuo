import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/ongs.dart';

// ─── MODEL ────────────────────────────────────────────────
class Servico {
  final String titulo;
  final String descricao;
  final String local;
  final String tempo;
  final String imagem;
  final String categoria;
  final String autor;
  final double avaliacao;
  final int totalAvaliacoes;

  Servico({
    required this.titulo,
    required this.descricao,
    required this.local,
    required this.tempo,
    required this.imagem,
    this.categoria = "Geral",
    this.autor = "Voluntário",
    this.avaliacao = 4.0,
    this.totalAvaliacoes = 0,
  });
}

// ─── DETALHE SERVIÇO ──────────────────────────────────────
class DetalheServico extends StatelessWidget {
  final Servico servico;

  const DetalheServico({super.key, required this.servico});

  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          servico.titulo,
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _verde,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'servico_${servico.titulo}',
              child: Image.asset(
                servico.imagem,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 220,
                    width: double.infinity,
                    color: const Color(0xFFB7D5B0),
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 50,
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _verde,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      servico.categoria.toUpperCase(),
                      style: GoogleFonts.quicksand(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    servico.titulo,
                    style: GoogleFonts.quicksand(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: _verdeMedio,
                      ),
                      const SizedBox(width: 4),
                      Text(servico.local),

                      const SizedBox(width: 12),

                      const Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: _verdeMedio,
                      ),
                      const SizedBox(width: 4),
                      Text(servico.tempo),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Text(
                    servico.descricao,
                    style: GoogleFonts.quicksand(
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _verde,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.info_outline),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Interesse registrado!"),
                          ),
                        );
                      },
                      label: Text(
                        "Saiba mais",
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TELA SERVIÇOS ────────────────────────────────────────
class Servicos extends StatefulWidget {
  final String nome;
  final int initialNavIndex;

  const Servicos({
    super.key,
    required this.nome,
    this.initialNavIndex = 1,
  });

  @override
  State<Servicos> createState() => _ServicosState();
}

class _ServicosState extends State<Servicos> {
  late int _bottomNavIndex;

  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  final List<Servico> _todosServicos = [
    Servico(
      titulo: "Aula de culinária",
      descricao:
          "Aprenda a fazer pratos deliciosos e saudáveis.",
      local: "Rio de Janeiro, RJ",
      tempo: "1h 30min",
      imagem: "assets/images/imagemcomida.jpg",
      categoria: "Culinária",
      autor: "Mariana Lopes",
      avaliacao: 5.0,
      totalAvaliacoes: 1024,
    ),

    Servico(
      titulo: "Jardinagem urbana",
      descricao:
          "Transforme seu espaço com plantas e hortas.",
      local: "São Paulo, SP",
      tempo: "2h",
      imagem: "assets/images/imagemjardineiro.jpg",
      categoria: "Jardinagem",
      autor: "Carlos Mendes",
      avaliacao: 4.5,
      totalAvaliacoes: 312,
    ),

    Servico(
      titulo: "Aula de violão",
      descricao:
          "Aprenda músicas populares e técnicas.",
      local: "Belo Horizonte, MG",
      tempo: "1h",
      imagem: "assets/images/violao.png",
      categoria: "Música",
      autor: "Ana Costa",
      avaliacao: 4.8,
      totalAvaliacoes: 87,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bottomNavIndex = widget.initialNavIndex;
  }

  void _onNavTap(int index) {
    if (index == _bottomNavIndex) return;

    if (index == 0) {
      Navigator.pop(context);
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => Ongs(
            nome: widget.nome,
            initialNavIndex: 2,
          ),
        ),
      );
    } else {
      setState(() {
        _bottomNavIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: _onNavTap,
        selectedItemColor: _verde,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Início",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work),
            label: "Serviços",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: "ONGs",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: "Chat",
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _verde,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    "Mútuo",
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(),

                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'logout') {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Login(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'logout',
                        child: Text("Sair"),
                      ),
                    ],
                    child: CircleAvatar(
                      backgroundColor: _bege,
                      child: Text(
                        widget.nome[0].toUpperCase(),
                        style: const TextStyle(
                          color: _verde,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _todosServicos.length,
                itemBuilder: (context, index) {
                  final servico = _todosServicos[index];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DetalheServico(servico: servico),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _branco,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                          ),
                        ],
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius:
                                const BorderRadius.only(
                              topLeft: Radius.circular(22),
                              topRight: Radius.circular(22),
                            ),
                            child: Hero(
                              tag:
                                  'servico_${servico.titulo}',
                              child: Image.asset(
                                servico.imagem,
                                height: 170,
                                width: double.infinity,
                                fit: BoxFit.cover,

                                errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return Container(
                                    height: 170,
                                    color: const Color(
                                      0xFFB7D5B0,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  servico.titulo,
                                  style:
                                      GoogleFonts.quicksand(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  servico.descricao,
                                  style:
                                      GoogleFonts.quicksand(
                                    color: Colors.grey[700],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: _verdeMedio,
                                    ),

                                    const SizedBox(width: 4),

                                    Text(servico.local),

                                    const Spacer(),

                                    const Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: _verdeMedio,
                                    ),

                                    const SizedBox(width: 4),

                                    Text(servico.tempo),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                SizedBox(
                                  width: double.infinity,
                                  child:
                                      ElevatedButton.icon(
                                    style:
                                        ElevatedButton.styleFrom(
                                      backgroundColor:
                                          _verde,
                                      foregroundColor:
                                          Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              DetalheServico(
                                            servico:
                                                servico,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.info_outline,
                                    ),
                                    label: const Text(
                                      "Saiba mais",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}