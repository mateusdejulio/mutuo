import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mutuo/login.dart';
import 'package:google_fonts/google_fonts.dart';

class Carregamento extends StatefulWidget {
  const Carregamento({super.key});

  @override
  State<Carregamento> createState() => _CarregamentoState();
}

class _CarregamentoState extends State<Carregamento> {
  int index = 0;

  final List<String> frases = [
    "Conectando pessoas, simplificando oportunidades.",
    "Seu caminho começa aqui.",
    "Juntos, fazemos mais acontecer.",
    "Transformando ideias em ações.",
    "Oportunidades que mudam vidas.",
  ];

  @override
  void initState() {
    super.initState();

    Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {
        index = (index + 1) % frases.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 88, 129, 87),
              Color.fromARGB(255, 58, 90, 64),
            ],
          ),
        ),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // LOGO
            Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB(255, 225, 220, 208),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Image.asset("assets/images/logo.png"),
              ),
            ),

            const SizedBox(height: 30),

            // ✨ FRASE COM ANIMAÇÃO
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  frases[index],
                  key: ValueKey<int>(index),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.quicksand(
                    fontSize: 18,
                    color: Colors.white,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const Spacer(flex: 3),

            // BOTÃO
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 225, 220, 208),
                    foregroundColor: const Color.fromARGB(255, 58, 90, 64),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Login()),
                    );
                  },
                  child: Text(
                    'Conheça nossos serviços',
                    style: GoogleFonts.quicksand(
                      fontSize: 18,
                      color: Color.fromARGB(255, 58, 90, 64),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
