// Modelo de uma conversa (linha da lista de chat), como retornado por
// GET /conversas/:tipo/:id.
class Conversa {
  final int id;
  final String tipoOutraConta;
  final String idOutraConta;
  final String? nomeOutraConta;
  final String? fotoOutraConta;
  final String? ultimaMensagem;
  final DateTime? ultimaMensagemEm;
  final int naoLidas;

  Conversa({
    required this.id,
    required this.tipoOutraConta,
    required this.idOutraConta,
    this.nomeOutraConta,
    this.fotoOutraConta,
    this.ultimaMensagem,
    this.ultimaMensagemEm,
    this.naoLidas = 0,
  });

  factory Conversa.fromJson(Map<String, dynamic> json) {
    return Conversa(
      id: int.parse(json['id'].toString()),
      tipoOutraConta: json['tipoOutraConta']?.toString() ?? '',
      idOutraConta: json['idOutraConta']?.toString() ?? '',
      nomeOutraConta: json['nomeOutraConta']?.toString(),
      fotoOutraConta: json['fotoOutraConta']?.toString(),
      ultimaMensagem: json['ultimaMensagem']?.toString(),
      ultimaMensagemEm: json['ultimaMensagemEm'] != null
          ? DateTime.tryParse(json['ultimaMensagemEm'].toString())
          : null,
      naoLidas: int.tryParse(json['naoLidas']?.toString() ?? '0') ?? 0,
    );
  }
}
