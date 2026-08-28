import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/mensagem.dart';
import 'api_service.dart';

// Encapsula a conexão Socket.io do chat em tempo real. Reconexão automática
// é o padrão do próprio pacote socket_io_client — não precisa lógica manual.
//
// É um singleton: o app mantém uma única conexão viva enquanto a sessão está
// logada (ver ChatSessaoService), então várias telas podem escutar os mesmos
// eventos. Cada `on...` devolve uma função que remove aquele listener.
class ChatSocketService {
  ChatSocketService._();
  static final ChatSocketService instance = ChatSocketService._();

  io.Socket? _socket;
  String? _tipo;
  String? _id;

  final List<void Function(Mensagem)> _listenersMensagemNova = [];
  final List<void Function(Mensagem)> _listenersMensagemEnviada = [];
  final List<void Function(int)> _listenersConversaLida = [];
  final List<void Function()> _listenersSolicitacaoNova = [];
  final List<void Function()> _listenersSolicitacaoAtualizada = [];

  bool get conectado => _socket != null;

  void conectar(String tipo, String id) {
    // Já conectado com a mesma conta: nada a fazer (chamada é idempotente).
    if (_socket != null && _tipo == tipo && _id == id) return;
    desconectar();

    _tipo = tipo;
    _id = id;

    final socket = io.io(ApiService.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    _socket = socket;

    socket.onConnect((_) {
      socket.emit('identificar', {'tipo': tipo, 'id': id});
    });

    socket.on('mensagem:nova', (data) {
      final mensagem = Mensagem.fromJson(Map<String, dynamic>.from(data));
      for (final callback in List.of(_listenersMensagemNova)) {
        callback(mensagem);
      }
    });

    socket.on('mensagem:enviada', (data) {
      final mensagem = Mensagem.fromJson(Map<String, dynamic>.from(data));
      for (final callback in List.of(_listenersMensagemEnviada)) {
        callback(mensagem);
      }
    });

    socket.on('conversa:lida', (data) {
      final conversaId = int.tryParse(data.toString());
      if (conversaId == null) return;
      for (final callback in List.of(_listenersConversaLida)) {
        callback(conversaId);
      }
    });

    // Payload não importa aqui: quem escuta apenas recarrega a contagem/lista
    // de solicitações a partir do servidor (mesmo padrão de `mensagem:nova`).
    socket.on('solicitacao:nova', (_) {
      for (final callback in List.of(_listenersSolicitacaoNova)) {
        callback();
      }
    });

    socket.on('solicitacao:atualizada', (_) {
      for (final callback in List.of(_listenersSolicitacaoAtualizada)) {
        callback();
      }
    });

    socket.connect();
  }

  void desconectar() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _tipo = null;
    _id = null;
  }

  void enviarMensagem(
    int conversaId,
    String tipo,
    String id,
    String conteudo,
  ) {
    _socket?.emit('mensagem:enviar', {
      'conversaId': conversaId,
      'tipo': tipo,
      'id': id,
      'conteudo': conteudo,
    });
  }

  void marcarComoLida(int conversaId, String tipo, String id) {
    _socket?.emit('conversa:lida', {
      'conversaId': conversaId,
      'tipo': tipo,
      'id': id,
    });
  }

  /// Registra um listener e devolve a função que o remove.
  void Function() onMensagemNova(void Function(Mensagem) callback) {
    _listenersMensagemNova.add(callback);
    return () => _listenersMensagemNova.remove(callback);
  }

  void Function() onMensagemEnviada(void Function(Mensagem) callback) {
    _listenersMensagemEnviada.add(callback);
    return () => _listenersMensagemEnviada.remove(callback);
  }

  void Function() onConversaLida(void Function(int) callback) {
    _listenersConversaLida.add(callback);
    return () => _listenersConversaLida.remove(callback);
  }

  void Function() onSolicitacaoNova(void Function() callback) {
    _listenersSolicitacaoNova.add(callback);
    return () => _listenersSolicitacaoNova.remove(callback);
  }

  void Function() onSolicitacaoAtualizada(void Function() callback) {
    _listenersSolicitacaoAtualizada.add(callback);
    return () => _listenersSolicitacaoAtualizada.remove(callback);
  }
}
