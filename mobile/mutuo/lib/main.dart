import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mutuo/carregamento.dart';
import 'package:mutuo/inicialUser.dart';
import 'package:mutuo/inicialOng.dart';
import 'package:mutuo/services/auth_service.dart';

void main() {
  runApp(const MeuApp());
}

// Usado por telas que precisam recarregar dados quando voltam a ficar
// visíveis (ex: lib/chat.dart recarregando a lista ao voltar de uma conversa).
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      title: 'Mútuo',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
      home: const _TelaInicial(),
    );
  }
}

/// Decide, ao abrir o app, se mostra a tela de boas-vindas
/// ou já leva direto pra Home de quem já estava logado.
class _TelaInicial extends StatefulWidget {
  const _TelaInicial();

  @override
  State<_TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<_TelaInicial> {
  @override
  void initState() {
    super.initState();
    _verificarSessao();
  }

  Future<void> _verificarSessao() async {
    final sessao = await AuthService.obterSessao();
    if (!mounted) return;

    if (sessao == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Carregamento()),
      );
      return;
    }

    if (sessao['tipo'] == 'ong') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              InicialOng(nome: sessao['nome']!, cnpj: sessao['id']!),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              InicialUsuario(nome: sessao['nome']!, cpf: sessao['id']!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color.fromARGB(255, 58, 90, 64),
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}