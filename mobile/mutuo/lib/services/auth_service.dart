import 'package:shared_preferences/shared_preferences.dart';

import 'chat_sessao_service.dart';
import 'solicitacao_sessao_service.dart';

/// Gerencia a sessão salva localmente (login persistente).
class AuthService {
  static const _kTipo = 'tipoLogin'; // 'usuario' ou 'ong'
  static const _kId = 'idLogin';     // cpf ou cnpj
  static const _kNome = 'nomeLogin';

  /// Salva a sessão de um usuário comum após login bem-sucedido.
  static Future<void> salvarLoginUsuario(String cpf, String nome) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTipo, 'usuario');
    await prefs.setString(_kId, cpf);
    await prefs.setString(_kNome, nome);
    await ChatSessaoService.instance.iniciar('usuario', cpf);
    await SolicitacaoSessaoService.instance.iniciar('usuario', cpf);
  }

  /// Salva a sessão de uma ONG após login bem-sucedido.
  static Future<void> salvarLoginOng(String cnpj, String nome) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTipo, 'ong');
    await prefs.setString(_kId, cnpj);
    await prefs.setString(_kNome, nome);
    await ChatSessaoService.instance.iniciar('ong', cnpj);
    await SolicitacaoSessaoService.instance.iniciar('ong', cnpj);
  }

  /// Retorna a sessão salva (ou null se não houver nenhuma).
  static Future<Map<String, String>?> obterSessao() async {
    final prefs = await SharedPreferences.getInstance();
    final tipo = prefs.getString(_kTipo);
    final id = prefs.getString(_kId);
    final nome = prefs.getString(_kNome);
    if (tipo == null || id == null || nome == null) return null;
    return {'tipo': tipo, 'id': id, 'nome': nome};
  }

  /// Apaga a sessão salva (chamado no logout).
  static Future<void> logout() async {
    // Único ponto por onde todas as telas saem: derruba socket e listeners.
    ChatSessaoService.instance.encerrar();
    SolicitacaoSessaoService.instance.encerrar();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTipo);
    await prefs.remove(_kId);
    await prefs.remove(_kNome);
  }
}