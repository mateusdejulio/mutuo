import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/conversa.dart';
import '../models/mensagem.dart';
import 'api_service.dart';
import 'chat_socket_service.dart';
import 'notificacao_local_service.dart';
import 'push_service.dart';

/// Mantém, enquanto a conta está logada, a conexão de socket viva e um listener
/// global de `mensagem:nova`. Se a mensagem não for da conversa aberta na tela,
/// dispara uma notificação local.
///
/// Iniciada no login e na retomada de sessão (main.dart) e encerrada no logout
/// (AuthService.logout).
class ChatSessaoService {
  ChatSessaoService._();
  static final ChatSessaoService instance = ChatSessaoService._();

  final ApiService _apiService = ApiService();

  // Cache de conversas para resolver nome/foto do remetente sem uma consulta
  // por mensagem recebida.
  final Map<int, Conversa> _conversas = {};

  String? _tipo;
  String? _id;
  int? _conversaAbertaId;
  void Function()? _cancelarListener;

  String? get tipo => _tipo;
  String? get id => _id;
  bool get ativa => _tipo != null && _id != null;

  /// Soma de `naoLidas` de todas as conversas — usado pro badge da aba
  /// "Chat" na navBar (ver [NavBadgeIcon]).
  final ValueNotifier<int> totalNaoLidas = ValueNotifier<int>(0);

  /// Como a notificação é exibida. Substituível nos testes.
  @visibleForTesting
  Future<void> Function(String titulo, String corpo, {String? payload})
  mostrarNotificacao = NotificacaoLocalService.mostrar;

  /// Informada pela tela de conversa (null quando ela sai de cena), para não
  /// notificar mensagem da conversa que já está na frente do usuário.
  void definirConversaAberta(int? conversaId) {
    _conversaAbertaId = conversaId;
  }

  Future<void> iniciar(String tipo, String id) async {
    if (_tipo == tipo && _id == id && _cancelarListener != null) return;
    encerrar();

    _tipo = tipo;
    _id = id;

    await NotificacaoLocalService.inicializar();
    await NotificacaoLocalService.pedirPermissao();
    // Push (Fase 5) cobre background/fechado; app aberto continua sendo o
    // socket + notificação local acima.
    await PushService.pedirPermissaoEEnviarToken(tipo, id);

    ChatSocketService.instance.conectar(tipo, id);
    _cancelarListener = ChatSocketService.instance.onMensagemNova(
      _aoReceberMensagem,
    );

    await _recarregarConversas();
    _recalcularTotalNaoLidas();
  }

  void encerrar() {
    _cancelarListener?.call();
    _cancelarListener = null;
    _conversaAbertaId = null;
    _tipo = null;
    _id = null;
    _conversas.clear();
    totalNaoLidas.value = 0;
    ChatSocketService.instance.desconectar();
  }

  /// Chamado pela tela de conversa ao marcar como lida, pra zerar o badge
  /// global na hora, sem esperar a lista de conversas recarregar do zero.
  void marcarConversaLidaLocal(int conversaId) {
    final conversa = _conversas[conversaId];
    if (conversa == null || conversa.naoLidas == 0) return;
    _conversas[conversaId] = conversa.copyWith(naoLidas: 0);
    _recalcularTotalNaoLidas();
  }

  void _recalcularTotalNaoLidas() {
    totalNaoLidas.value = _conversas.values.fold(
      0,
      (soma, c) => soma + c.naoLidas,
    );
  }

  Future<void> _aoReceberMensagem(Mensagem mensagem) async {
    final meuTipo = _tipo;
    final meuId = _id;
    if (meuTipo == null || meuId == null) return;

    // Mensagem própria (eco): não conta como não lida nem notifica.
    if (mensagem.ehMinha(meuTipo, meuId)) return;

    // Recalcula o badge a partir do servidor, que é quem decide de fato o
    // que conta como lido (a tela de conversa aberta já marca como lida
    // sozinha ao receber, então isso também cobre o caso de zerar de volta).
    try {
      await _recarregarConversas();
      _recalcularTotalNaoLidas();
    } catch (e) {
      debugPrint('Falha ao recalcular mensagens não lidas: $e');
    }

    // Da conversa já aberta na tela: não dispara notificação local.
    if (mensagem.conversaId == _conversaAbertaId) return;

    // Chamado de um callback do socket (sem await de quem dispara), então
    // nenhum erro aqui pode escapar como exceção não tratada.
    try {
      final conversa = await _buscarConversa(mensagem.conversaId);
      final nome = conversa?.nomeOutraConta ?? 'Nova mensagem';
      final foto = conversa?.fotoOutraConta;

      await mostrarNotificacao(
        nome,
        _previa(mensagem.conteudo),
        payload: jsonEncode({
          'conversaId': mensagem.conversaId,
          'meuTipo': meuTipo,
          'meuId': meuId,
          'nomeOutraConta': nome,
          'fotoOutraConta': (foto != null && foto.isNotEmpty)
              ? '${ApiService.baseUrl}$foto'
              : null,
        }),
      );
    } catch (e) {
      debugPrint('Falha ao notificar mensagem nova: $e');
    }
  }

  Future<Conversa?> _buscarConversa(int conversaId) async {
    if (_conversas.containsKey(conversaId)) return _conversas[conversaId];
    await _recarregarConversas();
    return _conversas[conversaId];
  }

  Future<void> _recarregarConversas() async {
    final meuTipo = _tipo;
    final meuId = _id;
    if (meuTipo == null || meuId == null) return;

    final dados = await _apiService.buscarConversas(meuTipo, meuId);
    for (final json in dados.whereType<Map<String, dynamic>>()) {
      final conversa = Conversa.fromJson(json);
      _conversas[conversa.id] = conversa;
    }
  }

  String _previa(String conteudo) {
    final texto = conteudo.trim();
    if (texto.length <= 100) return texto;
    return '${texto.substring(0, 100)}...';
  }
}
