import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/services/api_service.dart';

// ─── AVATAR REUTILIZÁVEL ────────────────────────────────────
// Busca a foto de perfil do usuário pelo cpf e exibe.
// Se não houver foto, ou falhar ao carregar, cai pras iniciais do nome.
// Usar em qualquer tela que tenha a "bolinha" do usuário no header.
class AvatarPerfil extends StatefulWidget {
  final String cpf;
  final String nome;
  final double radius;

  const AvatarPerfil({
    super.key,
    required this.cpf,
    required this.nome,
    this.radius = 20,
  });

  @override
  State<AvatarPerfil> createState() => _AvatarPerfilState();
}

class _AvatarPerfilState extends State<AvatarPerfil> {
  static const _bege = Color(0xFFDAD7CD);
  static const _verde = Color(0xFF3A5A40);

  final ApiService _api = ApiService();
  String? _fotoUrl;
  bool _carregado = false;

  @override
  void initState() {
    super.initState();
    _carregarFoto();
  }

  @override
  void didUpdateWidget(covariant AvatarPerfil oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se o cpf mudar (ex: trocou de usuário), busca a foto de novo.
    if (oldWidget.cpf != widget.cpf) {
      _carregado = false;
      _carregarFoto();
    }
  }

  Future<void> _carregarFoto() async {
    if (widget.cpf.isEmpty) {
      setState(() => _carregado = true);
      return;
    }
    final foto = await _api.buscarFotoPerfil(widget.cpf);
    if (!mounted) return;
    setState(() {
      _fotoUrl = foto;
      _carregado = true;
    });
  }

  String get _inicial =>
      widget.nome.isNotEmpty ? widget.nome[0].toUpperCase() : 'U';

  @override
  Widget build(BuildContext context) {
    final foto = _fotoUrl;
    if (!_carregado || foto == null || foto.isEmpty) {
      return _avatarIniciais();
    }
    return ClipOval(
      child: Image.network(
        '${ApiService.baseUrl}$foto',
        width: widget.radius * 2,
        height: widget.radius * 2,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _avatarIniciais();
        },
        errorBuilder: (context, error, stack) => _avatarIniciais(),
      ),
    );
  }

  Widget _avatarIniciais() {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: _bege,
      child: Text(
        _inicial,
        style: GoogleFonts.quicksand(
          fontSize: widget.radius * 0.9,
          fontWeight: FontWeight.bold,
          color: _verde,
        ),
      ),
    );
  }
}