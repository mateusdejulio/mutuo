import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Configuração da URL Base da sua API Express.
  // - Use 'http://10.0.2.2:3000' para o Emulador Android padrão.
  // - Use 'http://localhost:3000' se estiver testando no Flutter Web ou simulador iOS.
  // - Use o IP da sua máquina (ex: 'http://192.168.1.50:3000') para celular físico no mesmo Wi-Fi.
  static const String baseUrl = 'http://localhost:3000';

  // Header padrão para indicar que estamos enviando e esperando JSON
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  /// 1. ROTA DE AUTENTICAÇÃO (POST /login)
  Future<Map<String, dynamic>?> fazerLogin(String login, String senha) async {
    final url = Uri.parse('$baseUrl/login');
    
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'login': login,
          'senha': senha,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Erro no login (Status ${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      print('Falha de conexão no login: $e');
      return null;
    }
  }

  /// 2. ROTA DE CADASTRO DE USUÁRIOS (POST /usuarios)
  Future<Map<String, dynamic>> cadastrarUsuario(Map<String, dynamic> dadosDoUsuario) async {
    final url = Uri.parse('$baseUrl/usuarios');

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(dadosDoUsuario), // Transforma o mapa do Flutter no JSON que o Express espera
      );

      // Como seu Express já retorna um JSON estruturado com {sucesso: true, id} ou {sucesso: false, erro}
      // nós apenas decodificamos e devolvemos para a tela tratar
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Não foi possível conectar ao servidor backend: $e'
      };
    }
  }

  /// 3. ROTA DE LISTAGEM DE USUÁRIOS (GET /usuarios)
  Future<List<dynamic>> buscarUsuarios() async {
    final url = Uri.parse('$baseUrl/usuarios');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body); // Retorna a lista de usuários vinda do banco
      } else {
        print('Erro ao buscar usuários (Status ${response.statusCode})');
        return [];
      }
    } catch (e) {
      print('Falha de conexão ao buscar usuários: $e');
      return [];
    }
  }
}