import 'package:flutter/material.dart';
import 'package:mutuo/carregamento.dart';

void main() {
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mútuo',
      home: Carregamento(),
    );
  }
}

