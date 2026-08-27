import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Handler de mensagem em background/terminado. Roda em um isolate próprio
/// (não compartilha estado com o resto do app), então precisa inicializar o
/// Firebase de novo. Não precisa mostrar a notificação: quando a mensagem
/// FCM inclui bloco `notification` (como o backend sempre envia), o próprio
/// sistema operacional já exibe na bandeja fora do app em primeiro plano.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage mensagem) async {
  await Firebase.initializeApp();
}

/// Push via Firebase Cloud Messaging (Fase 5) — cobre app em background ou
/// fechado. Com o app aberto, quem trata mensagem nova é o ChatSessaoService
/// (via socket), então esta classe só cuida de token e do toque na notificação.
class PushService {
  static final ApiService _apiService = ApiService();

  static bool get _suportado =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Chamado no login (e na retomada de sessão): pede permissão, obtém o
  /// token FCM e registra no backend. Também reenvia se o token for
  /// rotacionado pelo sistema enquanto a conta segue logada.
  static Future<void> pedirPermissaoEEnviarToken(String tipo, String id) async {
    if (!_suportado) return;

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _apiService.enviarTokenNotificacao(
          tipo: tipo,
          identificador: id,
          token: token,
        );
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((novoToken) {
        _apiService.enviarTokenNotificacao(
          tipo: tipo,
          identificador: id,
          token: novoToken,
        );
      });
    } catch (e) {
      debugPrint('Falha ao configurar push (FCM): $e');
    }
  }

  /// Registra o toque em notificação com o app em background (volta ao
  /// primeiro plano) e, se o app foi aberto a partir de uma notificação
  /// (estava fechado), trata a mensagem que o abriu.
  static Future<void> configurarAoTocar(
    void Function(int conversaId) aoAbrirConversa,
  ) async {
    if (!_suportado) return;

    void tratar(RemoteMessage mensagem) {
      final conversaId = int.tryParse(mensagem.data['conversaId']?.toString() ?? '');
      if (conversaId != null) aoAbrirConversa(conversaId);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(tratar);

    final inicial = await FirebaseMessaging.instance.getInitialMessage();
    if (inicial != null) tratar(inicial);
  }
}
