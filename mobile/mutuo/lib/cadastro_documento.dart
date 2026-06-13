import 'package:flutter/material.dart';
import 'cadastro_endereco.dart';

class CadastroDocumento extends StatefulWidget {
  final String tipoConta;
  final String nome;
  final String email;
  final String senha;
  final String telefone;

  const CadastroDocumento({
    super.key,
    required this.tipoConta,
    required this.nome,
    required this.email,
    required this.senha,
    required this.telefone,
  });

  @override
  State<CadastroDocumento> createState() => _CadastroDocumentoState();
}

class _CadastroDocumentoState extends State<CadastroDocumento> {
  final _formKey = GlobalKey<FormState>();

  // Usuário
  final cpfController = TextEditingController();
  final dataNascController = TextEditingController();

  // ONG
  final cnpjController = TextEditingController();
  final nomeOngController = TextEditingController();
  final dataCriacaoController = TextEditingController();
  final focoController = TextEditingController();
  final descricaoController = TextEditingController();

  bool get _isOng => widget.tipoConta == "ong";

  @override
  void dispose() {
    cpfController.dispose();
    dataNascController.dispose();
    cnpjController.dispose();
    nomeOngController.dispose();
    dataCriacaoController.dispose();
    focoController.dispose();
    descricaoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(TextEditingController controller) async {
    final DateTime? data = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );

    if (data != null) {
      final formatada =
          "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";
      setState(() => controller.text = formatada);
    }
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
                    Text(
                      _isOng
                          ? "Etapa 2 de 3 — Dados da ONG"
                          : "Etapa 2 de 3 — Documento",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                            if (_isOng) ..._camposOng() else ..._camposUsuario(),

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
                                onPressed: () {
                                  if (!_formKey.currentState!.validate()) return;

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CadastroEndereco(
                                        tipoConta: widget.tipoConta,
                                        nome: widget.nome,
                                        email: widget.email,
                                        senha: widget.senha,
                                        telefone: widget.telefone,
                                        cpf: cpfController.text,
                                        dataNasc: dataNascController.text,
                                        cnpj: cnpjController.text,
                                        nomeOng: nomeOngController.text,
                                        dataCriacao: dataCriacaoController.text,
                                        foco: focoController.text,
                                        descricao: descricaoController.text,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Próximo",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
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

  List<Widget> _camposUsuario() {
    return [
      _label("CPF", Icons.badge),
      _input(
        controller: cpfController,
        hint: "000.000.000-00",
        keyboardType: TextInputType.number,
        validator: (v) {
          if (v!.isEmpty) return "Digite o CPF";
          final numeros = v.replaceAll(RegExp(r'[^0-9]'), '');
          if (numeros.length != 11) return "CPF deve ter 11 dígitos";
          return null;
        },
      ),

      const SizedBox(height: 15),

      _label("Data de nascimento", Icons.cake),
      _input(
        controller: dataNascController,
        hint: "DD/MM/AAAA",
        readOnly: true,
        onTap: () => _selecionarData(dataNascController),
        validator: (v) =>
            v!.isEmpty ? "Selecione a data de nascimento" : null,
      ),
    ];
  }

  List<Widget> _camposOng() {
    return [
      _label("Nome da ONG", Icons.business),
      _input(
        controller: nomeOngController,
        hint: "Nome fantasia da ONG",
        validator: (v) => v!.isEmpty ? "Digite o nome da ONG" : null,
      ),

      const SizedBox(height: 15),

      _label("CNPJ", Icons.badge),
      _input(
        controller: cnpjController,
        hint: "00.000.000/0000-00",
        keyboardType: TextInputType.number,
        validator: (v) {
          if (v!.isEmpty) return "Digite o CNPJ";
          final numeros = v.replaceAll(RegExp(r'[^0-9]'), '');
          if (numeros.length != 14) return "CNPJ deve ter 14 dígitos";
          return null;
        },
      ),


      const SizedBox(height: 15),

      _label("Data de criação", Icons.calendar_today),
      _input(
        controller: dataCriacaoController,
        hint: "DD/MM/AAAA",
        readOnly: true,
        onTap: () => _selecionarData(dataCriacaoController),
        validator: (v) => v!.isEmpty ? "Selecione a data de criação" : null,
      ),

      const SizedBox(height: 15),

      _label("Foco de atuação", Icons.flag),
      _input(
        controller: focoController,
        hint: "Ex: Animais, Educação, Idosos...",
        validator: (v) => v!.isEmpty ? "Digite o foco de atuação" : null,
      ),

      const SizedBox(height: 15),

      _label("Descrição", Icons.description),
      _input(
        controller: descricaoController,
        hint: "Conte um pouco sobre a ONG",
        maxLines: 4,
        validator: (v) => v!.isEmpty ? "Digite uma descrição" : null,
      ),
    ];
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
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFE5E2D8),
          suffixIcon: readOnly ? const Icon(Icons.calendar_month) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}