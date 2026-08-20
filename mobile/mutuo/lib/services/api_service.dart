import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // localhost funciona para Flutter Web no Chrome e simulador iOS
  // Para emulador Android: use 'http://10.0.2.2:3000'
  // Para celular físico: use o IP da sua máquina ex: 'http://143.106.241.23:3000' (certo)
  
  final String baseUrl = kReleaseMode
    ? 'https://mutuo-api.onrender.com' // URL do Render em produção[cite: 1]
    : 'http://localhost:3000';         // IP da máquina local durante desenvolvimento

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

  // ─── Busca os dados do dashboard (horas, trabalhos, pontos, plano) ───
  // Usa GET /usuarios/:cpf/dashboard
  Future<Map<String, dynamic>?> buscarDashboardUsuario(String cpf) async {
    final url = Uri.parse(
      '$baseUrl/usuarios/${Uri.encodeComponent(cpf)}/dashboard',
    );
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

  // ─── NOVO: busca os serviços em destaque (usuários premium) pro carrossel da tela inicial ───
  // Usa GET /servicos-destaque
  Future<List<dynamic>> buscarServicosDestaque() async {
    final url = Uri.parse('$baseUrl/servicos-destaque');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

    // ─── NOVO: busca TODOS os serviços ativos de usuários (tela de Serviços / busca) ───
  // Usa GET /servicos-usuario
  Future<List<dynamic>> buscarTodosServicos() async {
    final url = Uri.parse('$baseUrl/servicos-usuario');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        return [];
      }
      return [];
    } catch (e) {
      return [];
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

  // ─── NOVO: cadastra um serviço oferecido pelo usuário ───
// Usa POST /servicos (multer, campo do arquivo precisa se chamar
// exatamente 'imagem', igual configurado no seu index.js -> uploadServico).
// A imagem é opcional: se não vier, o serviço é criado sem foto.
Future<Map<String, dynamic>> cadastrarServico({
  required String cpf,
  required String nomeServico,
  required String descricao,
  required String foco,
  required String duracao,
  List<int>? imagemBytes,
  String? imagemNome,
}) async {
  final url = Uri.parse('$baseUrl/servicos');
  try {
    final request = http.MultipartRequest('POST', url);
    request.fields['cpf'] = cpf;
    request.fields['nomeServico'] = nomeServico;
    request.fields['descricao'] = descricao;
    request.fields['foco'] = foco;
    request.fields['duracao'] = duracao;

    if (imagemBytes != null && imagemNome != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'imagem',
          imagemBytes,
          filename: imagemNome,
          contentType: _mimeTypeDaExtensao(imagemNome),
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body);
  } catch (e) {
    return {
      'sucesso': false,
      'erro': 'Não foi possível conectar ao servidor: $e',
    };
  }
}

  // ─── Busca a foto de perfil do usuário ───
  // Usa GET /perfil/foto/:cpf
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

  // ─── NOVO: envia/troca a foto de perfil do usuário ───
  // Usa POST /perfil/foto (multer, campo do arquivo precisa se chamar
  // exatamente 'fotoPerfil', igual configurado no seu index.js).
  // Recebe bytes + nome do arquivo em vez de XFile diretamente, pra não
  // acoplar esse service ao pacote image_picker.
  Future<Map<String, dynamic>> enviarFotoPerfil(
    String cpf,
    List<int> bytes,
    String nomeArquivo,
  ) async {
    final url = Uri.parse('$baseUrl/perfil/foto');
    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['cpf'] = cpf;
      request.files.add(
        http.MultipartFile.fromBytes(
          'fotoPerfil',
          bytes,
          filename: nomeArquivo,
          contentType: _mimeTypeDaExtensao(nomeArquivo),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Não foi possível conectar ao servidor: $e',
      };
    }
  }

  // Detecta o mimetype certo pela extensão do arquivo, pois o Flutter Web
  // nem sempre expõe o content-type real da imagem escolhida no seletor.
  MediaType _mimeTypeDaExtensao(String nomeArquivo) {
    final ext = nomeArquivo.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }
}