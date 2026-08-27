import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mutuo/carregamento.dart';
import 'package:mutuo/conversaChat.dart';
import 'package:mutuo/inicialUser.dart';
import 'package:mutuo/inicialOng.dart';
import 'package:mutuo/models/conversa.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:mutuo/services/auth_service.dart';
import 'package:mutuo/services/chat_sessao_service.dart';
import 'package:mutuo/services/notificacao_local_service.dart';
import 'package:mutuo/services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificacaoLocalService.inicializar();
  NotificacaoLocalService.aoTocar = _abrirConversaDaNotificacao;
  PushService.configurarAoTocar(_abrirConversaPorId);

  runApp(const MeuApp());
}

// Usado por telas que precisam recarregar dados quando voltam a ficar
// visíveis (ex: lib/chat.dart recarregando a lista ao voltar de uma conversa).
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Necessário para navegar a partir do toque em uma notificação, que acontece
// fora da árvore de widgets (sem BuildContext).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Abre a conversa da notificação tocada (payload montado em ChatSessaoService).
void _abrirConversaDaNotificacao(String payload) {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  try {
    final dados = jsonDecode(payload) as Map<String, dynamic>;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ConversaChat(
          conversaId: int.parse(dados['conversaId'].toString()),
          meuTipo: dados['meuTipo'].toString(),
          meuId: dados['meuId'].toString(),
          nomeOutraConta: dados['nomeOutraConta']?.toString() ?? 'Conta',
          fotoOutraConta: dados['fotoOutraConta']?.toString(),
        ),
      ),
    );
  } catch (_) {
    // Payload inválido: só ignora o toque.
  }
}

/// Abre a conversa a partir do toque em uma notificação push (FCM), cujo
/// payload traz só o `conversaId` — resolve nome/foto do outro participante
/// consultando a lista de conversas antes de navegar.
Future<void> _abrirConversaPorId(int conversaId) async {
  final sessao = await AuthService.obterSessao();
  if (sessao == null) return;

  final meuTipo = sessao['tipo']!;
  final meuId = sessao['id']!;

  final dados = await ApiService().buscarConversas(meuTipo, meuId);
  Conversa? conversa;
  for (final json in dados.whereType<Map<String, dynamic>>()) {
    final c = Conversa.fromJson(json);
    if (c.id == conversaId) {
      conversa = c;
      break;
    }
  }

  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  navigator.push(
    MaterialPageRoute(
      builder: (_) => ConversaChat(
        conversaId: conversaId,
        meuTipo: meuTipo,
        meuId: meuId,
        nomeOutraConta: conversa?.nomeOutraConta ?? 'Conta',
        fotoOutraConta: conversa?.fotoOutraConta != null
            ? '${ApiService.baseUrl}${conversa!.fotoOutraConta}'
            : null,
      ),
    ),
  );
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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

    // Sessão retomada: liga o chat (socket + notificações) desde o início.
    await ChatSessaoService.instance.iniciar(sessao['tipo']!, sessao['id']!);
    if (!mounted) return;

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