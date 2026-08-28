import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // localhost funciona para Flutter Web no Chrome e simulador iOS
  // Para emulador Android: use 'http://10.0.2.2:3000'
  // Para celular físico: use o IP da sua máquina ex: 'http://143.106.241.23:3000' (certo)

  static const String baseUrl = 'https://mutuo-api.onrender.com';

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

  // ══════════════════════════════════════════════════════════
  // NOVO: bloco de dados da ONG (tela inicial da ONG)
  // ══════════════════════════════════════════════════════════

  // ─── Busca os dados completos da ONG + pontos ───
  // Usa GET /ongs/:cnpj
  Future<Map<String, dynamic>?> buscarOngPorCnpj(String cnpj) async {
    final url = Uri.parse('$baseUrl/ongs/${Uri.encodeComponent(cnpj)}');
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

  // ─── NOVO: busca o resumo + lista de certificados emitidos pela ONG ───
  // Usa GET /certificados/ong/:cnpj
  Future<Map<String, dynamic>?> buscarCertificadosOng(String cnpj) async {
    final url = Uri.parse(
      '$baseUrl/certificados/ong/${Uri.encodeComponent(cnpj)}',
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

  // ─── Busca os serviços (atividades) cadastrados pela ONG ───
  // Usa GET /servicos/ong/:cnpj
  Future<List<dynamic>> buscarServicosOng(String cnpj) async {
    final url = Uri.parse('$baseUrl/servicos/ong/${Uri.encodeComponent(cnpj)}');
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

  // ─── Busca as solicitações recebidas pela ONG (usada pra contar voluntários) ───
  // Usa GET /solicitacoes-ong/prestador/:cnpj
  Future<List<dynamic>> buscarSolicitacoesOng(String cnpj) async {
    final url = Uri.parse(
      '$baseUrl/solicitacoes-ong/prestador/${Uri.encodeComponent(cnpj)}',
    );
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

  // ─── Busca as solicitações recebidas por um usuário como prestador ───
  // (tela de Notificações/Solicitações) — Usa GET /solicitacoes/prestador/:cpf
  Future<List<dynamic>> buscarSolicitacoesPrestador(String cpf) async {
    final url = Uri.parse(
      '$baseUrl/solicitacoes/prestador/${Uri.encodeComponent(cpf)}',
    );
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

  // ─── Conta solicitações não lidas de um usuário prestador (badge) ───
  // Usa GET /solicitacoes/naolidas/:cpf
  Future<int> contarSolicitacoesNaoLidas(String cpf) async {
    final url = Uri.parse(
      '$baseUrl/solicitacoes/naolidas/${Uri.encodeComponent(cpf)}',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return int.tryParse(data['total']?.toString() ?? '0') ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── Marca uma solicitação (usuário-prestador) como lida ───
  // Usa PUT /solicitacoes/:cod/lida
  Future<void> marcarSolicitacaoLida(dynamic codSolicitacao) async {
    final url = Uri.parse('$baseUrl/solicitacoes/$codSolicitacao/lida');
    try {
      await http.put(url, headers: _headers);
    } catch (e) {
      // Notificação é acessório: falha aqui não deve travar a tela.
    }
  }

  // ─── Conta solicitações não lidas recebidas por uma ONG (badge) ───
  // Usa GET /solicitacoes-ong/naolidas/:cnpj
  Future<int> contarSolicitacoesNaoLidasOng(String cnpj) async {
    final url = Uri.parse(
      '$baseUrl/solicitacoes-ong/naolidas/${Uri.encodeComponent(cnpj)}',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return int.tryParse(data['total']?.toString() ?? '0') ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── Marca uma solicitação (ONG-prestadora) como lida ───
  // Usa PUT /solicitacoes-ong/:cod/lida
  Future<void> marcarSolicitacaoOngLida(dynamic codSolicitacao) async {
    final url = Uri.parse('$baseUrl/solicitacoes-ong/$codSolicitacao/lida');
    try {
      await http.put(url, headers: _headers);
    } catch (e) {
      // Notificação é acessório: falha aqui não deve travar a tela.
    }
  }

  // ─── Cria uma solicitação de um usuário pro serviço de outro usuário ───
  // Usa POST /solicitacoes
  Future<Map<String, dynamic>> cadastrarSolicitacao({
    required String codServico,
    required String codUsuario,
    int pontos = 0,
  }) async {
    final url = Uri.parse('$baseUrl/solicitacoes');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'codServico': codServico,
          'codUsuario': codUsuario,
          'pontos': pontos,
        }),
      );
      final dados = jsonDecode(response.body);
      if (response.statusCode == 200 && dados['error'] == null) {
        return {'sucesso': true, ...dados};
      }
      return {'sucesso': false, 'erro': dados['erro'] ?? 'Não foi possível enviar a solicitação.'};
    } catch (e) {
      return {'sucesso': false, 'erro': 'Não foi possível conectar ao servidor.'};
    }
  }

  // ─── Cria uma solicitação de um usuário pra atividade de uma ONG ───
  // Usa POST /solicitacoes-ong
  Future<Map<String, dynamic>> cadastrarSolicitacaoOng({
    required String codServico,
    required String codUsuario,
    int pontos = 0,
  }) async {
    final url = Uri.parse('$baseUrl/solicitacoes-ong');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'codServico': codServico,
          'codUsuario': codUsuario,
          'pontos': pontos,
        }),
      );
      final dados = jsonDecode(response.body);
      if (response.statusCode == 200 && dados['error'] == null) {
        return {'sucesso': true, ...dados};
      }
      return {'sucesso': false, 'erro': dados['erro'] ?? 'Não foi possível enviar a solicitação.'};
    } catch (e) {
      return {'sucesso': false, 'erro': 'Não foi possível conectar ao servidor.'};
    }
  }

  // ─── Aceita/recusa uma solicitação recebida (lado usuário-prestador) ───
  // Usa PUT /solicitacoes/:cod
  Future<Map<String, dynamic>> alterarSolicitacao(
    dynamic codSolicitacao, {
    required String statusS,
    required String statusE,
    required dynamic pontos,
  }) async {
    final url = Uri.parse('$baseUrl/solicitacoes/$codSolicitacao');
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({'statusS': statusS, 'statusE': statusE, 'pontos': pontos}),
      );
      final dados = jsonDecode(response.body);
      if (response.statusCode == 200 && dados['error'] == null) {
        return {'sucesso': true, ...dados};
      }
      return {'sucesso': false, 'erro': dados['erro'] ?? 'Não foi possível atualizar a solicitação.'};
    } catch (e) {
      return {'sucesso': false, 'erro': 'Não foi possível conectar ao servidor.'};
    }
  }

  // ─── Aceita/recusa uma solicitação recebida (lado ONG) ───
  // Usa PUT /solicitacoes-ong/:cod
  Future<Map<String, dynamic>> alterarSolicitacaoOng(
    dynamic codSolicitacao, {
    required String statusS,
    required String statusE,
    required dynamic pontos,
  }) async {
    final url = Uri.parse('$baseUrl/solicitacoes-ong/$codSolicitacao');
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({'statusS': statusS, 'statusE': statusE, 'pontos': pontos}),
      );
      final dados = jsonDecode(response.body);
      if (response.statusCode == 200 && dados['error'] == null) {
        return {'sucesso': true, ...dados};
      }
      return {'sucesso': false, 'erro': dados['erro'] ?? 'Não foi possível atualizar a solicitação.'};
    } catch (e) {
      return {'sucesso': false, 'erro': 'Não foi possível conectar ao servidor.'};
    }
  }

  // ─── Busca a foto de perfil da ONG ───
  // Usa GET /perfil/foto/ong/:cnpj
  Future<String?> buscarFotoPerfilOng(String cnpj) async {
    final url = Uri.parse(
      '$baseUrl/perfil/foto/ong/${Uri.encodeComponent(cnpj)}',
    );
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

  // ─── Atualiza nome/email/telefone da ONG ───
  // Usa PUT /ongs/:cnpj/perfil
  Future<Map<String, dynamic>> atualizarOng(
    String cnpj,
    Map<String, dynamic> dados,
  ) async {
    final url = Uri.parse('$baseUrl/ongs/${Uri.encodeComponent(cnpj)}/perfil');
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

    // ─── Ativa o plano Premium da ONG (simulação de assinatura) ───
  // Usa PUT /ongs/:cnpj/premium
  Future<Map<String, dynamic>> ativarPremiumOng(String cnpj) async {
    final url = Uri.parse('$baseUrl/ongs/${Uri.encodeComponent(cnpj)}/premium');
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({'premium': 1}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Não foi possível conectar ao servidor: $e',
      };
    }
  }

  // ─── Cancela o plano Premium da ONG ───
  // Usa PUT /ongs/:cnpj/premium (mesma rota, premium: 0)
  Future<Map<String, dynamic>> cancelarPremiumOng(String cnpj) async {
    final url = Uri.parse('$baseUrl/ongs/${Uri.encodeComponent(cnpj)}/premium');
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({'premium': 0}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Não foi possível conectar ao servidor: $e',
      };
    }
  }



  // ─── Cadastra uma atividade/serviço oferecido pela ONG ───
  // Usa POST /servicos/ong (multer, campo do arquivo precisa se chamar
  // exatamente 'imagem', igual configurado no index.js -> uploadServico).
  Future<Map<String, dynamic>> cadastrarServicoOng({
    required String cnpj,
    required String nomeServico,
    required String descricao,
    required String foco,
    required String duracao,
    List<int>? imagemBytes,
    String? imagemNome,
  }) async {
    final url = Uri.parse('$baseUrl/servicos/ong');
    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['cnpj'] = cnpj;
      request.fields['nomeServico'] = nomeServico;
      request.fields['descricao'] = descricao;
      request.fields['foco'] = foco.trim().toLowerCase();
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

  // ─── Excluir (desativar) uma atividade da ONG ───
  // Usa PATCH /servicos/ong/:id/status
  Future<Map<String, dynamic>> excluirServicoOng(String id) async {
    final url = Uri.parse('$baseUrl/servicos/ong/$id/status');
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

  // ─── Envia/troca a foto de perfil da ONG ───
  // Usa POST /perfil/foto/ong (multer, campo do arquivo precisa se chamar
  // exatamente 'fotoPerfil', igual configurado no index.js).
  Future<Map<String, dynamic>> enviarFotoPerfilOng(
    String cnpj,
    List<int> bytes,
    String nomeArquivo,
  ) async {
    final url = Uri.parse('$baseUrl/perfil/foto/ong');
    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['cnpj'] = cnpj;
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

  // ─── Atualiza uma atividade existente da ONG ───
  // Usa PUT /servicos/ong/:id (multer, campo 'imagem' opcional — só
  // manda se o usuário trocar a foto na edição)
  Future<Map<String, dynamic>> atualizarServicoOng({
    required String id,
    required String nomeServico,
    required String descricao,
    required String foco,
    required String duracao,
    List<int>? imagemBytes,
    String? imagemNome,
  }) async {
    final url = Uri.parse('$baseUrl/servicos/ong/$id');
    try {
      final request = http.MultipartRequest('PUT', url);
      request.fields['nomeServico'] = nomeServico;
      request.fields['descricao'] = descricao;
      request.fields['foco'] = foco.trim().toLowerCase();
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

  // ─── NOVO: busca os serviços em destaque (usuários premium) pro carrossel da tela inicial ───
  // Usa GET /servicos-destaque. Passa o cpf do usuário logado pra API excluir
  // os próprios serviços do resultado (ver AND s.idUsuario != ? em db.js).
  Future<List<dynamic>> buscarServicosDestaque({String? cpf}) async {
    final url = Uri.parse(
      '$baseUrl/servicos-destaque${cpf != null ? '?cpf=${Uri.encodeComponent(cpf)}' : ''}',
    );
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

  // ─── NOVO: busca TODAS as atividades ativas de ONGs (tela de ONGs) ───
  // Usa GET /servicos-ong
  Future<List<dynamic>> buscarTodosServicosOng() async {
    final url = Uri.parse('$baseUrl/servicos-ong');
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

    // ─── Ativa o plano Premium do usuário comum (simulação de assinatura) ───
  // Usa PUT /usuarios/:cpf/premium
  Future<Map<String, dynamic>> ativarPremiumUsuario(String cpf) async {
    final url = Uri.parse(
      '$baseUrl/usuarios/${Uri.encodeComponent(cpf)}/premium',
    );
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({'premium': 1}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Não foi possível conectar ao servidor: $e',
      };
    }
  }

  // ─── Cancela o plano Premium do usuário comum ───
  // Usa PUT /usuarios/:cpf/premium (mesma rota, premium: 0)
  Future<Map<String, dynamic>> cancelarPremiumUsuario(String cpf) async {
    final url = Uri.parse(
      '$baseUrl/usuarios/${Uri.encodeComponent(cpf)}/premium',
    );
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({'premium': 0}),
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
      request.fields['foco'] = foco.trim().toLowerCase();
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

  // ─── Atualiza um serviço existente do usuário ───
  // Usa PUT /servicos/:id (multer, campo 'imagem' opcional — só
  // manda se o usuário trocar a foto na edição)
  Future<Map<String, dynamic>> atualizarServico({
    required String id,
    required String nomeServico,
    required String descricao,
    required String foco,
    required String duracao,
    List<int>? imagemBytes,
    String? imagemNome,
  }) async {
    final url = Uri.parse('$baseUrl/servicos/$id');
    try {
      final request = http.MultipartRequest('PUT', url);
      request.fields['nomeServico'] = nomeServico;
      request.fields['descricao'] = descricao;
      request.fields['foco'] = foco.trim().toLowerCase();
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

  // ─── NOVO: busca o resumo + lista de certificados do usuário ───
  // Usa GET /certificados/:cpf
  Future<Map<String, dynamic>?> buscarCertificadosUsuario(String cpf) async {
    final url = Uri.parse('$baseUrl/certificados/${Uri.encodeComponent(cpf)}');
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

  // ─── Busca (ou cria) a conversa entre duas contas ───
  // Usa POST /conversas
  Future<Map<String, dynamic>> buscarOuCriarConversa({
    required String tipo1,
    required String id1,
    required String tipo2,
    required String id2,
  }) async {
    final url = Uri.parse('$baseUrl/conversas');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'tipo1': tipo1,
          'id1': id1,
          'tipo2': tipo2,
          'id2': id2,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Não foi possível conectar ao servidor: $e',
      };
    }
  }

  // ─── Lista as conversas de uma conta (tela de Chat) ───
  // Usa GET /conversas/:tipo/:id
  Future<List<dynamic>> buscarConversas(String tipo, String id) async {
    final url = Uri.parse(
      '$baseUrl/conversas/${Uri.encodeComponent(tipo)}/${Uri.encodeComponent(id)}',
    );
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

  // ─── Busca o histórico de mensagens de uma conversa ───
  // Usa GET /conversas/:conversaId/mensagens (opcionalmente só as novas, com ?desde=)
  Future<List<dynamic>> buscarMensagens(
    int conversaId, {
    String? desde,
    required String meuTipo,
    required String meuId,
  }) async {
    final params = <String, String>{'tipo': meuTipo, 'id': meuId};
    if (desde != null) params['desde'] = desde;
    final url = Uri.parse('$baseUrl/conversas/$conversaId/mensagens')
        .replace(queryParameters: params);
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

  // ─── Limpa o histórico da conversa só pro lado de quem chamou ───
  // Usa PUT /conversas/:conversaId/limpar
  Future<Map<String, dynamic>> limparConversa(
    int conversaId, {
    required String meuTipo,
    required String meuId,
  }) async {
    final url = Uri.parse('$baseUrl/conversas/$conversaId/limpar');
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({'tipo': meuTipo, 'id': meuId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'sucesso': false,
        'erro': 'Não foi possível conectar ao servidor: $e',
      };
    }
  }

  // ─── Registra o token FCM do dispositivo para push (Fase 5) ───
  // Usa POST /notificacoes/token
  Future<Map<String, dynamic>> enviarTokenNotificacao({
    required String tipo,
    required String identificador,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/notificacoes/token');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'tipo': tipo,
          'identificador': identificador,
          'token': token,
        }),
      );
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
