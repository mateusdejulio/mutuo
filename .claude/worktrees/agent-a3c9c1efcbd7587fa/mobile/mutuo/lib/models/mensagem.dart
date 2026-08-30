// Modelo de uma mensagem de chat, como retornado pela API/Socket.io
// (colunas de Mutuo_Mensagem: conversa_id, tipo_remetente, id_remetente, enviada_em).
class Mensagem {
  final int id;
  final int conversaId;
  final String tipoRemetente;
  final String idRemetente;
  final String conteudo;
  final DateTime? enviadaEm;
  final bool lida;

  Mensagem({
    required this.id,
    required this.conversaId,
    required this.tipoRemetente,
    required this.idRemetente,
    required this.conteudo,
    this.enviadaEm,
    this.lida = false,
  });

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    return Mensagem(
      id: int.parse(json['id'].toString()),
      conversaId: int.parse(json['conversa_id'].toString()),
      tipoRemetente: json['tipo_remetente']?.toString() ?? '',
      idRemetente: json['id_remetente']?.toString() ?? '',
      conteudo: json['conteudo']?.toString() ?? '',
      enviadaEm: json['enviada_em'] != null
          ? DateTime.tryParse(json['enviada_em'].toString())
          : null,
      lida: _paraBool(json['lida']),
    );
  }

  // Campos TINYINT do MySQL podem chegar como bool, int ou String.
  static bool _paraBool(dynamic valor) {
    return valor == true || valor == 1 || valor == '1';
  }

  bool ehMinha(String meuTipo, String meuId) =>
      tipoRemetente == meuTipo && idRemetente == meuId;

  Mensagem copyWith({bool? lida}) {
    return Mensagem(
      id: id,
      conversaId: conversaId,
      tipoRemetente: tipoRemetente,
      idRemetente: idRemetente,
      conteudo: conteudo,
      enviadaEm: enviadaEm,
      lida: lida ?? this.lida,
    );
  }
}
