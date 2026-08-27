import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificações locais (app aberto). O disparo fica em [ChatSessaoService],
/// que é quem escuta `mensagem:nova` enquanto a sessão está ativa.
class NotificacaoLocalService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _canalId = 'mutuo_chat';
  static const _canalNome = 'Mensagens';
  static const _canalDescricao = 'Mensagens novas do chat do Mútuo';

  static bool _inicializado = false;
  static int _proximoId = 0;

  /// Chamado quando o usuário toca em uma notificação, com o payload dela.
  /// Registrado em `main.dart`, que é quem tem acesso ao navegador.
  static void Function(String payload)? aoTocar;

  // O plugin só tem implementação para as plataformas que o app usa de fato;
  // em desktop o initialize exigiria settings próprias e lançaria erro.
  static bool get _suportado =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> inicializar() async {
    if (_inicializado || !_suportado) return;
    _inicializado = true;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    // Notificação é acessório: se o plugin falhar, o chat continua funcionando.
    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (resposta) {
          final payload = resposta.payload;
          if (payload != null && payload.isNotEmpty) aoTocar?.call(payload);
        },
      );
    } catch (e) {
      debugPrint('Falha ao inicializar notificações locais: $e');
    }
  }

  /// Pede permissão de notificação (Android 13+ e iOS pedem em runtime).
  static Future<void> pedirPermissao() async {
    if (!_suportado) return;

    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Falha ao pedir permissão de notificação: $e');
    }
  }

  static Future<void> mostrar(
    String titulo,
    String corpo, {
    String? payload,
  }) async {
    if (!_suportado) return;
    await inicializar();

    const detalhes = NotificationDetails(
      android: AndroidNotificationDetails(
        _canalId,
        _canalNome,
        channelDescription: _canalDescricao,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.show(
        id: _proximoId++,
        title: titulo,
        body: corpo,
        notificationDetails: detalhes,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Falha ao mostrar notificação local: $e');
    }
  }
}
