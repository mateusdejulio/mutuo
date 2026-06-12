import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mutuo/services/api_service.dart';
import 'inicialUser.dart';
import 'inicialOng.dart';

class CadastroEndereco extends StatefulWidget {
  final String tipoConta;
  final String nome;
  final String email;
  final String senha;
  final String telefone;

  // Usuário
  final String cpf;
  final String dataNasc;

  // ONG
  final String cnpj;
  final String nomeOng;
  final String dataCriacao;
  final String foco;
  final String descricao;

  const CadastroEndereco({
    super.key,
    required this.tipoConta,
    required this.nome,
    required this.email,
    required this.senha,
    required this.telefone,
    this.cpf = '',
    this.dataNasc = '',
    this.cnpj = '',
    this.nomeOng = '',
    this.dataCriacao = '',
    this.foco = '',
    this.descricao = '',
  });

  @override
  State<CadastroEndereco> createState() => _CadastroEnderecoState();
}

class _CadastroEnderecoState extends State<CadastroEndereco> {
  final _formKey = GlobalKey<FormState>();

  final cepController = TextEditingController();
  final enderecoController = TextEditingController();
  final bairroController = TextEditingController();
  final cidadeController = TextEditingController();

  String? estadoSelecionado;
  bool _buscandoCep = false;
  bool _carregando = false;

  bool get _isOng => widget.tipoConta == "ong";

  static const List<String> _estados = [
    "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO",
    "MA", "MT", "MS", "MG", "PA", "PB", "PR", "PE", "PI",
    "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO",
  ];

  @override
  void dispose() {
    cepController.dispose();
    enderecoController.dispose();
    bairroController.dispose();
    cidadeController.dispose();
    super.dispose();
  }

  Future<void> _buscarCep() async {
    final cep = cepController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cep.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("CEP deve ter 8 dígitos")),
      );
      return;
    }

    setState(() => _buscandoCep = true);

    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cep/json/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['erro'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("CEP não encontrado")),
          );
        } else {
          setState(() {
            enderecoController.text = data['logradouro'] ?? '';
            bairroController.text = data['bairro'] ?? '';
            cidadeController.text = data['localidade'] ?? '';
            estadoSelecionado = data['uf'];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao buscar CEP. Verifique sua conexão.")),
      );
    } finally {
      setState(() => _buscandoCep = false);
    }
  }

  Future<void> _finalizarCadastro() async {
    if (!_formKey.currentState!.validate()) return;

    if (estadoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione o estado")),
      );
      return;
    }

    setState(() => _carregando = true);

    final api = ApiService();
    Map<String, dynamic> resultado;

    if (_isOng) {
      resultado = await api.cadastrarOng({
        'nomeOng': widget.nomeOng,
        'cnpj': widget.cnpj.replaceAll(RegExp(r'[^0-9]'), ''),
        'email': widget.email,
        'nomeResponsavel': widget.nome,
        'telefone': widget.telefone,
        'cidade': cidadeController.text,
        'bairro': bairroController.text,
        'endereco': enderecoController.text,
        'uf': estadoSelecionado,
        'senha': widget.senha,
        'foco': widget.foco,
        'descricao': widget.descricao,
        'dataCriacao': _converterData(widget.dataCriacao),
      });
    } else {
      resultado = await api.cadastrarUsuario({
        'cpf': widget.cpf.replaceAll(RegExp(r'[^0-9]'), ''),
        'nome': widget.nome,
        'email': widget.email,
        'senha': widget.senha,
        'telefone': widget.telefone,
        'cidade': cidadeController.text,
        'bairro': bairroController.text,
        'cep': cepController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'nascimento': _converterData(widget.dataNasc),
        'uf': estadoSelecionado,
        'endereco': enderecoController.text,
        'cadastro': DateTime.now().toIso8601String().substring(0, 10),
      });
    }

    setState(() => _carregando = false);

    if (resultado['sucesso'] == true) {
      if (!mounted) return;

      if (_isOng) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => InicialOng(nome: widget.nomeOng)),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => InicialUsuario(nome: widget.nome)),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['erro']?.toString() ?? "Erro ao cadastrar"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Converte "DD/MM/AAAA" -> "AAAA-MM-DD" (formato MySQL)
  String _converterData(String data) {
    if (data.isEmpty) return '';
    final partes = data.split('/');
    if (partes.length != 3) return '';
    return "${partes[2]}-${partes[1]}-${partes[0]}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/fundo.png", fit: BoxFit.cover),
          ),

          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                const SizedBox(height: 10),

                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE5E2D8),
                      ),
                      child: ClipOval(
                        child: Image.asset("assets/images/logo.png"),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Mútuo",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Etapa 3 de 3 — Endereço",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Flexible(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4E7A57),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label("CEP", Icons.location_pin),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _input(
                                    controller: cepController,
                                    hint: "00000-000",
                                    keyboardType: TextInputType.number,
                                    validator: (v) =>
                                        v!.isEmpty ? "Digite o CEP" : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  margin: const EdgeInsets.only(top: 5),
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6C946F),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    onPressed: _buscandoCep ? null : _buscarCep,
                                    child: _buscandoCep
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.search, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 15),

                            _label("Endereço", Icons.home),
                            _input(
                              controller: enderecoController,
                              hint: "Rua, número",
                              validator: (v) =>
                                  v!.isEmpty ? "Digite o endereço" : null,
                            ),

                            const SizedBox(height: 15),

                            _label("Bairro", Icons.map),
                            _input(
                              controller: bairroController,
                              hint: "Seu bairro",
                              validator: (v) =>
                                  v!.isEmpty ? "Digite o bairro" : null,
                            ),

                            const SizedBox(height: 15),

                            _label("Cidade", Icons.location_city),
                            _input(
                              controller: cidadeController,
                              hint: "Sua cidade",
                              validator: (v) =>
                                  v!.isEmpty ? "Digite a cidade" : null,
                            ),

                            const SizedBox(height: 15),

                            _label("Estado", Icons.flag),
                            Container(
                              margin: const EdgeInsets.only(top: 5),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E2D8),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: estadoSelecionado,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                                hint: const Text("Selecione o estado"),
                                items: _estados
                                    .map((uf) => DropdownMenuItem(
                                          value: uf,
                                          child: Text(uf),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => estadoSelecionado = value);
                                },
                              ),
                            ),

                            const SizedBox(height: 25),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C946F),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: _carregando ? null : _finalizarCadastro,
                                child: _carregando
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        "Finalizar cadastro",
                                        style: TextStyle(color: Colors.white),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Center(
                              child: TextButton(
                                onPressed: _carregando
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text(
                                  "Voltar",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String texto, IconData icone) {
    return Row(
      children: [
        Icon(icone, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Text(texto, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFE5E2D8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}