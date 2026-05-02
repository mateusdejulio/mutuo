import 'package:flutter/material.dart';
import 'inicialUser.dart';
import 'inicialOng.dart';

class Cadastro extends StatefulWidget {
  const Cadastro({super.key});

  @override
  State<Cadastro> createState() => _CadastroState();
}

class _CadastroState extends State<Cadastro> {
  final _formKey = GlobalKey<FormState>();

  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final telefoneController = TextEditingController();

  String? tipoConta;

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
                            _label("Nome", Icons.person),
                            _input(
                              controller: nomeController,
                              hint: "Seu nome completo",
                              validator: (v) =>
                                  v!.isEmpty ? "Digite seu nome" : null,
                            ),

                            const SizedBox(height: 15),

                            _label("Email", Icons.email),
                            _input(
                              controller: emailController,
                              hint: "seu@email.com",
                              validator: (v) {
                                if (v!.isEmpty) return "Digite seu email";
                                if (!v.contains("@")) return "Email inválido";
                                return null;
                              },
                            ),

                            const SizedBox(height: 15),

                            _label("Telefone", Icons.phone),
                            _input(
                              controller: telefoneController,
                              hint: "(19) 99999-9999",
                              keyboardType: TextInputType.phone,
                              validator: (v) =>
                                  v!.isEmpty ? "Digite seu telefone" : null,
                            ),

                            const SizedBox(height: 20),

                            _label("Tipo de conta", Icons.group),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: _tipoCard(
                                    titulo: "Usuário",
                                    icone: Icons.person,
                                    selecionado: tipoConta == "usuario",
                                    onTap: () {
                                      setState(() {
                                        tipoConta = "usuario";
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _tipoCard(
                                    titulo: "ONG",
                                    icone: Icons.business,
                                    selecionado: tipoConta == "ong",
                                    onTap: () {
                                      setState(() {
                                        tipoConta = "ong";
                                      });
                                    },
                                  ),
                                ),
                              ],
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
                                onPressed: () {
                                  if (!_formKey.currentState!.validate())
                                    return;

                                  if (tipoConta == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Selecione o tipo de conta",
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (tipoConta == "usuario") {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InicialUsuario(
                                          nome: nomeController.text,
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InicialOng(
                                          nome: nomeController.text,
                                        ),
                                      ),
                                    );
                                  }
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

  Widget _tipoCard({
    required String titulo,
    required IconData icone,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 100,
        decoration: BoxDecoration(
          color: selecionado
              ? Colors.white.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selecionado ? Colors.white : Colors.white30,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, color: Colors.white),
            const SizedBox(height: 5),
            Text(titulo, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
