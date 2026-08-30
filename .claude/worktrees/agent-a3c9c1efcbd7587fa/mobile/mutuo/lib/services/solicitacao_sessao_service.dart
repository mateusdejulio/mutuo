import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'chat_socket_service.dart';
import 'notificacao_local_service.dart';

/// Mesmo papel do [ChatSessaoService], mas pro badge/notificação de
/// solicitações de serviço recebidas (bell da navBar). Compartilha a MESMA
/// conexão de socket (via [ChatSocketService]) já mantida viva pelo chat —
/// aqui só registramos listeners a mais nela.
///
/// Iniciado no login e na retomada de sessão (main.dart) e encerrado no
/// logout (AuthService.logout).
class SolicitacaoSessaoService {
  SolicitacaoSessaoService._();
  static final SolicitacaoSessaoService instance = SolicitacaoSessaoService._();

  final ApiService _apiService = ApiService();

  String? _tipo;
  String? _id;
  void Function()? _cancelarNova;
  void Function()? _cancelarAtualizada;

  /// Total de solicitações não lidas — usado pro badge do sino nas telas.
  final ValueNotifier<int> totalNaoLidas = ValueNotifier<int>(0);

  Future<void> iniciar(String tipo, String id) async {
    if (_tipo == tipo && _id == id && _cancelarNova != null) return;
    encerrar();

    _tipo = tipo;
    _id = id;

    ChatSocketService.instance.conectar(tipo, id);
    _cancelarNova = ChatSocketService.instance.onSolicitacaoNova(_aoChegarSolicitacao);
    _cancelarAtualizada = ChatSocketService.instance.onSolicitacaoAtualizada(_aoAtualizarSolicitacao);

    await recarregar();
  }

  void encerrar() {
    _cancelarNova?.call();
    _cancelarNova = null;
    _cancelarAtualizada?.call();
    _cancelarAtualizada = null;
    _tipo = null;
    _id = null;
    totalNaoLidas.value = 0;
  }

  /// Recalcula o badge a partir do servidor. Público pra telas (ex: depois de
  /// abrir/aceitar/recusar uma solicitação) forçarem a atualização na hora,
  /// sem esperar o próximo evento de socket.
  Future<void> recarregar() async {
    final tipo = _tipo;
    final id = _id;
    if (tipo == null || id == null) return;

    final total = tipo == 'usuario'
        ? await _apiService.contarSolicitacoesNaoLidas(id)
        : await _apiService.contarSolicitacoesNaoLidasOng(id);
    totalNaoLidas.value = total;
  }

  Future<void> _aoChegarSolicitacao() async {
    try {
      await recarregar();
      await NotificacaoLocalService.mostrar(
        'Nova solicitação',
        'Você recebeu uma nova solicitação de serviço.',
        payload: '{"tipo":"solicitacao"}',
      );
    } catch (e) {
      debugPrint('Falha ao tratar nova solicitação: $e');
    }
  }

  Future<void> _aoAtualizarSolicitacao() async {
    try {
      await recarregar();
    } catch (e) {
      debugPrint('Falha ao recarregar solicitações: $e');
    }
  }
}
