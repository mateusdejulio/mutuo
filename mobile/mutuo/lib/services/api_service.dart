import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // localhost funciona para Flutter Web no Chrome e simulador iOS
  // Para emulador Android: use 'http://10.0.2.2:3000'
  // Para celular físico: use o IP da sua máquina ex: 'http://192.168.1.50:3000'
  static const String baseUrl = 'http://localhost:3000';

  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };


  Future<Map<String, dynamic>> cadastrarOng(Map<String, dynamic> dadosDaOng) async {
    final url = Uri.parse('$baseUrl/ongs');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(dadosDaOng),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'sucesso': false, 'erro': 'Não foi possível conectar ao servidor backend: $e'};
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

  Future<Map<String, dynamic>> fazerLoginUsuario(String email, String senha) async {
    final url = Uri.parse('$baseUrl/loginUsuario');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({'email': email, 'senha': senha}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Não foi possível conectar ao servidor: $e'};
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
      return {'sucesso': false, 'mensagem': 'Não foi possível conectar ao servidor: $e'};
    }
  }

  Future<Map<String, dynamic>> cadastrarUsuario(Map<String, dynamic> dadosDoUsuario) async {
    final url = Uri.parse('$baseUrl/usuarios');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(dadosDoUsuario),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'sucesso': false, 'erro': 'Não foi possível conectar ao servidor backend: $e'};
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
}