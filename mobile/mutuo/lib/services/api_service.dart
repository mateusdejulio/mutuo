import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // localhost funciona para Flutter Web no Chrome e simulador iOS
  // Para emulador Android: use 'http://10.0.2.2:3000'
  // Para celular físico: use o IP da sua máquina ex: 'http://143.106.241.23:3000' (certo)
  static const String baseUrl = 'http://localhost:3000';

  final Map<String, String> _headers = {'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> cadastrarOng(
    Map<String, dynamic> dadosDaOng,
  ) async {
    final url = Uri.parse('$baseUrl/ongs');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(dadosDaOng),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Não foi possível conectar ao servidor backend: $e',
      };
    }
  }

  Future<Map<String, dynamic>?> fazerLogin(String login, String senha) async {
    final url = Uri.parse('$baseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({'login': login, 'senha': senha}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> fazerLoginUsuario(
    String email,
    String senha,
  ) async {
    final url = Uri.parse('$baseUrl/loginUsuario');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({'email': email, 'senha': senha}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor: $e',
      };
    }
  }

  Future<Map<String, dynamic>> fazerLoginOng(String email, String senha) async {
    final url = Uri.parse('$baseUrl/loginOng');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({'email': email, 'senha': senha}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'mensagem': 'Não foi possível conectar ao servidor: $e',
      };
    }
  }

  Future<Map<String, dynamic>> cadastrarUsuario(
    Map<String, dynamic> dadosDoUsuario,
  ) async {
    final url = Uri.parse('$baseUrl/usuarios');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(dadosDoUsuario),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Não foi possível conectar ao servidor backend: $e',
      };
    }
  }

  Future<List<dynamic>> buscarUsuarios() async {
    final url = Uri.parse('$baseUrl/usuarios');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  // ─── Busca um usuário específico pelo CPF ───
  // Usa GET /usuarios/:cpf (rota dedicada, traz todos os campos inclusive telefone)
  Future<Map<String, dynamic>?> buscarUsuarioPorCpf(String cpf) async {
    final url = Uri.parse('$baseUrl/usuarios/${Uri.encodeComponent(cpf)}');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Atualiza nome/email/telefone do usuário ───
  // Usa PUT /usuarios/:cpf/perfil
  Future<Map<String, dynamic>> atualizarUsuario(
    String cpf,
    Map<String, dynamic> dados,
  ) async {
    final url = Uri.parse(
      '$baseUrl/usuarios/${Uri.encodeComponent(cpf)}/perfil',
    );
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode(dados),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Não foi possível conectar ao servidor: $e',
      };
    }
  }

  // ─── Serviços do usuário logado ───
  Future<List<dynamic>> buscarServicosDoUsuario(String cpf) async {
    final url = Uri.parse(
      '$baseUrl/servicos/usuario/${Uri.encodeComponent(cpf)}',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        if (data is Map && data['servicos'] is List) return data['servicos'];
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ─── Excluir (desativar) um serviço ───
  Future<Map<String, dynamic>> excluirServico(String id) async {
    final url = Uri.parse('$baseUrl/servicos/$id/status');
    try {
      final response = await http.patch(
        url,
        headers: _headers,
        body: jsonEncode({'ativo': 0}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Não foi possível conectar ao servidor: $e',
      };
    }
  }

  // ─── NOVO: busca a foto de perfil do usuário ───
  // Usa GET /perfil/foto/:cpf, que já existe no backend e retorna
  // { fotoPerfil: '/uploads/fotos/arquivo.jpg' } ou { fotoPerfil: null }
  Future<String?> buscarFotoPerfil(String cpf) async {
    final url = Uri.parse('$baseUrl/perfil/foto/${Uri.encodeComponent(cpf)}');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['fotoPerfil'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
