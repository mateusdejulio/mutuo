import 'package:flutter/material.dart';
import 'package:mutuo/cadastro.dart';
import 'package:mutuo/inicialUser.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
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

            // 🧠 "Cabeça"
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
            SizedBox(height: 50),
            // 🧍 "Corpo"
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
                        color: Color.fromARGB(255, 58, 90, 64),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 📧 Email
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: const TextStyle(
                          color: Color.fromARGB(255, 58, 90, 64),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(
                              255,
                              58,
                              90,
                              64,
                            ), // 👈 SUA COR
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🔒 Senha
                    TextField(
                      controller: senhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Senha",
                        labelStyle: TextStyle(
                          color: Color.fromARGB(255, 58, 90, 64),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(
                              255,
                              58,
                              90,
                              64,
                            ), // 👈 SUA COR
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 🚀 Botão login
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            58,
                            90,
                            64,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          print(emailController.text);
                          print(senhaController.text);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  InicialUsuario(nome: emailController.text),
                            ),
                          );
                        },
                        child: const Text(
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
                        style: TextStyle(
                          color: Color.fromARGB(255, 58, 90, 64),
                        ),
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Cadastro()),
                        );
                      },
                      child: const Text(
                        "Não possui cadastro? Clique aqui!",
                        style: TextStyle(
                          color: Color.fromARGB(255, 58, 90, 64),
                        ),
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
