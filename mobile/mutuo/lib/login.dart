import 'package:flutter/material.dart';
import 'package:mutuo/cadastro.dart';
import 'package:mutuo/inicialUser.dart';
import 'package:mutuo/inicialOng.dart';
import 'package:mutuo/services/api_service.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  bool _carregando = false;

  static const _verde = Color.fromARGB(255, 58, 90, 64);

  Future<void> _fazerLogin() async {
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      _mostrarErro('Preencha o email e a senha.');
      return;
    }

    setState(() => _carregando = true);

    final api = ApiService();

    // Tenta como usuário primeiro
    final resUsuario = await api.fazerLoginUsuario(email, senha);

    if (resUsuario['sucesso'] == true) {
      final nome = resUsuario['usuario']['nome'] ?? email;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => InicialUsuario(nome: nome)),
      );
      return;
    }

    // Se não for usuário, tenta como ONG
    final resOng = await api.fazerLoginOng(email, senha);

    if (resOng['sucesso'] == true) {
      final nome = resOng['usuario']['nomeOng'] ?? email;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => InicialOng(nome: nome)),
      );
      return;
    }

    // Nenhum deu certo
    setState(() => _carregando = false);
    _mostrarErro(resUsuario['mensagem'] ?? 'Email ou senha incorretos.');
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/fundo.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 120),

            // Cabeça
            Transform.translate(
              offset: const Offset(0, 40),
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.fromARGB(255, 225, 220, 208),
                ),
                child: ClipOval(
                  child: Image.asset(
                    "assets/images/logo.png",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 50),

            // Corpo
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(30, 80, 30, 30),
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 225, 220, 208),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(175),
                    topRight: Radius.circular(175),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Bem-vindo de volta!",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _verde,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Email
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: const TextStyle(color: _verde),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: _verde, width: 2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Senha
                    TextField(
                      controller: senhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Senha",
                        labelStyle: const TextStyle(color: _verde),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: _verde, width: 2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Botão Entrar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _verde,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _carregando ? null : _fazerLogin,
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
                                "Entrar",
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        "Esqueci minha senha",
                        style: TextStyle(color: _verde),
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Cadastro()),
                        );
                      },
                      child: const Text(
                        "Não possui cadastro? Clique aqui!",
                        style: TextStyle(color: _verde),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}