import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/mensagem.dart';
import 'api_service.dart';

// Encapsula a conexão Socket.io do chat em tempo real. Reconexão automática
// é o padrão do próprio pacote socket_io_client — não precisa lógica manual.
class ChatSocketService {
  io.Socket? _socket;

  void conectar(String tipo, String id) {
    _socket = io.io(ApiService.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.onConnect((_) {
      _socket!.emit('identificar', {'tipo': tipo, 'id': id});
    });

    _socket!.connect();
  }

  void desconectar() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
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

  void onMensagemNova(void Function(Mensagem) callback) {
    _socket?.on('mensagem:nova', (data) {
      callback(Mensagem.fromJson(Map<String, dynamic>.from(data)));
    });
  }

  void onMensagemEnviada(void Function(Mensagem) callback) {
    _socket?.on('mensagem:enviada', (data) {
      callback(Mensagem.fromJson(Map<String, dynamic>.from(data)));
    });
  }

  void onConversaLida(void Function(int) callback) {
    _socket?.on('conversa:lida', (data) {
      callback(int.parse(data.toString()));
    });
  }

  void removerListeners() {
    _socket?.off('mensagem:nova');
    _socket?.off('mensagem:enviada');
    _socket?.off('conversa:lida');
  }
}
