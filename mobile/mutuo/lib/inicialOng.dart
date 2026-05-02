import 'package:flutter/material.dart';

class InicialOng extends StatelessWidget {
  final String nome;

  const InicialOng({super.key, required this.nome});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ONG"),
        backgroundColor: const Color(0xFF3A5A40),
      ),
      body: Center(
        child: Text(
          "Bem-vindo, $nome 🏢",
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}