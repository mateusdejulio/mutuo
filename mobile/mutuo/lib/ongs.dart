import 'package:flutter/material.dart';
import 'package:mutuo/widgets/chat_badge_icon.dart';
import 'package:mutuo/widgets/notificacao_badge_icon.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/chat.dart';
import 'package:mutuo/conversaChat.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/notificacoes.dart';
import 'package:mutuo/servicos.dart';
import 'package:mutuo/quem_somos.dart';
import 'package:mutuo/widgets/avatar_perfil.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:mutuo/perfil.dart';
import 'package:mutuo/services/auth_service.dart';

// ─── MODEL ────────────────────────────────────────────────
// Representa uma atividade de ONG vinda do banco (rota /servicos-ong)
class Ong {
  final String? id;
  final String titulo;
  final String descricao;
  final String local;
  final String tempo;
  final String imagem;
  final String? imagemUrl;
  final String categoria;
  final String nomeOng;
  final String? cnpjOng;
  final String? fotoOngUrl;
  final double avaliacao;
  final int totalAvaliacoes;
  final int pontos;

  Ong({
    this.id,
    required this.titulo,
    required this.descricao,
    required this.local,
    required this.tempo,
    required this.imagem,
    this.imagemUrl,
    this.categoria = "Geral",
    this.nomeOng = "ONG",
    this.cnpjOng,
    this.fotoOngUrl,
    this.avaliacao = 4.0,
    this.totalAvaliacoes = 0,
    this.pontos = 0,
  });

  factory Ong.fromJson(Map<String, dynamic> json) {
    final horas = json['horas'];
    final caminhoImagem = json['imagem']?.toString();
    final caminhoFoto = json['fotoOng']?.toString();
    return Ong(
      id: json['id']?.toString(),
      titulo: json['nomeServico']?.toString() ?? '',
      descricao: json['descricao']?.toString() ?? '',
      local: [
        json['cidade'],
        json['estado'],
      ].where((v) => v != null && v.toString().isNotEmpty).join(', '),
      tempo: horas != null ? '${horas}h' : '',
      imagem: caminhoImagem ?? '',
      imagemUrl: (caminhoImagem != null && caminhoImagem.isNotEmpty)
          ? '${ApiService.baseUrl}$caminhoImagem'
          : null,
      categoria: (json['foco']?.toString().isNotEmpty ?? false)
          ? json['foco'].toString()
          : 'Geral',
      nomeOng: (json['nomeOng']?.toString().isNotEmpty ?? false)
          ? json['nomeOng'].toString()
          : 'ONG',
      cnpjOng: json['cnpj']?.toString(),
      fotoOngUrl: (caminhoFoto != null && caminhoFoto.isNotEmpty)
          ? '${ApiService.baseUrl}$caminhoFoto'
          : null,
      pontos: int.tryParse('${json['pontos'] ?? 0}') ?? 0,
    );
  }
}

// ─── DETALHE ONG ──────────────────────────────────────────
class DetalheOng extends StatelessWidget {
  final Ong ong;
  final String meuCpf;

  const DetalheOng({super.key, required this.ong, required this.meuCpf});

  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'ong_${ong.id}',
                  child: ong.imagemUrl != null
                      ? Image.network(
                          ong.imagemUrl!,
                          height: 280,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _semFotoServico(height: 280),
                        )
                      : _semFotoServico(height: 280),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Color(0xFF344E41),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: Color(0xFFF4A261),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${ong.pontos} pts",
                            style: GoogleFonts.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF344E41),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                decoration: const BoxDecoration(
                  color: _branco,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ong.titulo,
                      style: GoogleFonts.quicksand(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2D3319),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _verde.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _verde.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.volunteer_activism_rounded,
                            color: _verde,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          ong.nomeOng,
                          style: GoogleFonts.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF344E41),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: _verdeMedio,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ong.local,
                          style: GoogleFonts.quicksand(
                            fontSize: 13,
                            color: const Color(0xFF6B705C),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: _verdeMedio,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ong.tempo,
                          style: GoogleFonts.quicksand(
                            fontSize: 13,
                            color: const Color(0xFF6B705C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(height: 1, color: const Color(0xFFEDEAE5)),
                    const SizedBox(height: 22),
                    Text(
                      "Sobre a atividade",
                      style: GoogleFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF344E41),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ong.descricao,
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        height: 1.6,
                        color: const Color(0xFF6B705C),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _verde,
                              side: BorderSide(
                                color: _verde.withOpacity(0.4),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => _abrirChatComOng(context),
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              "Tirar dúvidas",
                              style: GoogleFonts.quicksand(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _verde,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => _solicitar(context),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              "Quero participar",
                              style: GoogleFonts.quicksand(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _solicitar(BuildContext context) async {
    final codServico = ong.id;
    if (codServico == null || codServico.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível enviar a solicitação.")),
      );
      return;
    }

    final resultado = await ApiService().cadastrarSolicitacaoOng(
      codServico: codServico,
      codUsuario: meuCpf,
      pontos: ong.pontos,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado['sucesso'] == true
              ? "Solicitação enviada!"
              : (resultado['erro']?.toString() ?? "Não foi possível enviar a solicitação."),
        ),
        backgroundColor: resultado['sucesso'] == true ? null : Colors.redAccent,
      ),
    );
  }

  // ─── Abre (ou cria) a conversa com a ONG dona da atividade ───
  Future<void> _abrirChatComOng(BuildContext context) async {
    final cnpj = ong.cnpjOng;
    if (cnpj == null || cnpj.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível abrir o chat.")),
      );
      return;
    }

    final resultado = await ApiService().buscarOuCriarConversa(
      tipo1: "usuario",
      id1: meuCpf,
      tipo2: "ong",
      id2: cnpj,
    );
    if (!context.mounted) return;

    final conversa = resultado['conversa'];
    if (resultado['sucesso'] != true || conversa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível abrir o chat.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversaChat(
          conversaId: int.parse(conversa['id'].toString()),
          meuTipo: "usuario",
          meuId: meuCpf,
          nomeOutraConta: ong.nomeOng,
          fotoOutraConta: ong.fotoOngUrl,
        ),
      ),
    );
  }
}

// ─── TELA ONGs ────────────────────────────────────────────
class Ongs extends StatefulWidget {
  final String nome;
  final String cpf;
  final int initialNavIndex;

  const Ongs({
    super.key,
    required this.nome,
    required this.cpf,
    this.initialNavIndex = 2,
  });

  @override
  State<Ongs> createState() => _OngsState();
}

class _OngsState extends State<Ongs> {
  late int _bottomNavIndex;
  String _categoriaSelecionada = "Todos";
  final TextEditingController _buscaController = TextEditingController();
  String _busca = "";

  final ApiService _apiService = ApiService();
  List<Ong> _todasOngs = [];
  bool _carregando = true;

  // ─── Paleta ───────────────────────────────────────────────
  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;

  // ─── categorias montadas dinamicamente a partir das atividades cadastradas ───
  List<String> get _categorias {
    final focosUnicos =
        _todasOngs
            .map((o) => o.categoria)
            .where((f) => f.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ["Todos", ...focosUnicos];
  }

  List<Ong> get _ongsFiltradas {
    return _todasOngs.where((o) {
      final categoriaOk =
          _categoriaSelecionada == "Todos" ||
          o.categoria == _categoriaSelecionada;
      final buscaOk =
          _busca.isEmpty ||
          o.titulo.toLowerCase().contains(_busca.toLowerCase()) ||
          o.nomeOng.toLowerCase().contains(_busca.toLowerCase());
      return categoriaOk && buscaOk;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _bottomNavIndex = widget.initialNavIndex;
    _carregarOngs();
  }

  // ─── Busca as atividades reais das ONGs na API ───
  Future<void> _carregarOngs() async {
    final dados = await _apiService.buscarTodosServicosOng();
    if (!mounted) return;

    setState(() {
      _todasOngs = dados
          .whereType<Map<String, dynamic>>()
          .map((json) => Ong.fromJson(json))
          .toList();
      _carregando = false;

      if (!_categorias.contains(_categoriaSelecionada)) {
        _categoriaSelecionada = "Todos";
      }
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == _bottomNavIndex) return;
    if (index == 0) {
      Navigator.pop(context);
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, __, ___) =>
              Servicos(nome: widget.nome, cpf: widget.cpf, initialNavIndex: 1),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Chat(
            tipoConta: "usuario",
            identificador: widget.cpf,
            nome: widget.nome,
          ),
        ),
      );
    } else {
      setState(() => _bottomNavIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _ongsFiltradas;

    return Scaffold(
      backgroundColor: _fundo,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroBusca(),
                    const SizedBox(height: 20),

                    // Contador + ações
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            _carregando
                                ? "Carregando atividades..."
                                : "${filtradas.length} atividades encontradas",
                            style: GoogleFonts.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B705C),
                            ),
                          ),
                          const Spacer(),
                          _chipAcao(
                            icone: Icons.tune_rounded,
                            label: "Filtros",
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    if (!_carregando) _chipsCategorias(),
                    const SizedBox(height: 20),

                    if (_carregando)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: CircularProgressIndicator(color: _verde),
                        ),
                      )
                    else if (filtradas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 40,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _branco,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE0DDD8)),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                color: _verdeMedio,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Nenhuma atividade encontrada",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B705C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: filtradas.length,
                        itemBuilder: (context, index) =>
                            _ongCard(filtradas[index]),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────
  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _verde,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      child: Row(
        children: [
          Text(
            "Mútuo",
            style: GoogleFonts.quicksand(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _branco,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Notificacoes(
                  tipoConta: 'usuario',
                  identificador: widget.cpf,
                  nome: widget.nome,
                ),
              ),
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _verdeMedio.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const NotificacaoBadgeIcon(),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await AuthService.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => Login()),
                  (route) => false,
                );
              } else if (value == 'meu_perfil') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PerfilUsuario(
                      cpf: widget.cpf,
                      nomeInicial: widget.nome,
                    ),
                  ),
                );
              } else if (value == 'quem_somos') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        QuemSomos(nome: widget.nome, cpf: widget.cpf),
                  ),
                );
              }
            },
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'meu_perfil',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18, color: _verde),
                    const SizedBox(width: 8),
                    Text(
                      "Meu Perfil",
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'quem_somos',
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: _verde),
                    const SizedBox(width: 8),
                    Text(
                      "Quem somos",
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 18, color: _verde),
                    const SizedBox(width: 8),
                    Text(
                      "Sair",
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            child: AvatarPerfil(cpf: widget.cpf, nome: widget.nome, radius: 20),
          ),
        ],
      ),
    );
  }

  // ─── HERO BUSCA ───────────────────────────────────────────
  Widget _heroBusca() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: _verde,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Encontre serviços solidários e apoie ONGs",
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _branco,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Troque serviços com ONGs e contribua para uma rede solidária que transforma ações voluntárias em impacto social real.",
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: _branco.withOpacity(0.80),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: _branco,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search_rounded,
                  color: _verde.withOpacity(0.5),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _buscaController,
                    onChanged: (v) => setState(() => _busca = v),
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      color: const Color(0xFF344E41),
                    ),
                    decoration: InputDecoration(
                      hintText: "Buscar atividades de ONGs...",
                      hintStyle: GoogleFonts.quicksand(
                        fontSize: 14,
                        color: const Color(0xFF9E9E9E),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _busca = _buscaController.text),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _verdeMedio,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      "Buscar",
                      style: GoogleFonts.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _branco,
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

  // ─── CHIP AÇÃO ────────────────────────────────────────────
  Widget _chipAcao({
    required IconData icone,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _branco,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDD9D3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icone, size: 15, color: _verde),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF344E41),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CHIPS CATEGORIAS (dinâmicas, vindas do banco) ─────────
  Widget _chipsCategorias() {
    final categorias = _categorias;

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categorias.length,
        itemBuilder: (context, index) {
          final cat = categorias[index];
          final selecionado = cat == _categoriaSelecionada;
          return GestureDetector(
            onTap: () => setState(() => _categoriaSelecionada = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selecionado ? _verde : _branco,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selecionado ? _verde : const Color(0xFFDDD9D3),
                  width: 1,
                ),
                boxShadow: selecionado
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Text(
                cat,
                style: GoogleFonts.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selecionado ? _branco : const Color(0xFF344E41),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── CARD ONG ─────────────────────────────────────────────
  Widget _ongCard(Ong ong) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetalheOng(ong: ong, meuCpf: widget.cpf)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: _branco,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem + tag
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: Stack(
                children: [
                  Hero(
                    tag: 'ong_${ong.id}',
                    child: ong.imagemUrl != null
                        ? Image.network(
                            ong.imagemUrl!,
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _semFotoServico(height: 170),
                          )
                        : _semFotoServico(height: 170),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _verde,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ong.categoria.toUpperCase(),
                        style: GoogleFonts.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _branco,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ong.titulo,
                    style: GoogleFonts.quicksand(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2D3319),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ong.descricao,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      color: const Color(0xFF6B705C),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ONG responsável
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _verde.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _verde.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.volunteer_activism_rounded,
                          color: _verde,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ong.nomeOng,
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF344E41),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Local + Tempo
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: _verdeMedio,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          ong.local,
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            color: const Color(0xFF6B705C),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: _verdeMedio,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        ong.tempo,
                        style: GoogleFonts.quicksand(
                          fontSize: 12,
                          color: const Color(0xFF6B705C),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Botão
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _verde,
                        foregroundColor: _branco,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.info_outline, size: 16),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetalheOng(ong: ong, meuCpf: widget.cpf)),
                      ),
                      label: Text(
                        "Saiba mais",
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BOTTOM NAV ───────────────────────────────────────────
  Widget _buildBottomNav() {
    final List<_NavItem> navItems = [
      _NavItem(
        icon: Icons.home_rounded,
        outlinedIcon: Icons.home_outlined,
        label: "Início",
      ),
      _NavItem(
        icon: Icons.work_rounded,
        outlinedIcon: Icons.work_outline_rounded,
        label: "Serviços",
      ),
      _NavItem(
        icon: Icons.favorite_rounded,
        outlinedIcon: Icons.favorite_border_rounded,
        label: "ONGs",
      ),
      _NavItem(
        icon: Icons.chat_bubble_rounded,
        outlinedIcon: Icons.chat_bubble_outline_rounded,
        label: "Chat",
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _branco,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomNavigationBar(
          currentIndex: _bottomNavIndex,
          onTap: _onNavTap,
          backgroundColor: _branco,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedItemColor: _verde,
          unselectedItemColor: const Color(0xFFADB5BD),
          selectedLabelStyle: GoogleFonts.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          items: List.generate(navItems.length, (i) {
            final item = navItems[i];
            final isSelected = _bottomNavIndex == i;
            return BottomNavigationBarItem(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _verde.withOpacity(0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: item.label == 'Chat'
                    ? ChatBadgeIcon(
                        icon: isSelected ? item.icon : item.outlinedIcon,
                      )
                    : Icon(
                        isSelected ? item.icon : item.outlinedIcon,
                        size: 22,
                      ),
              ),
              label: item.label,
            );
          }),
        ),
      ),
    );
  }
}

// ─── Placeholder exibido quando o serviço não tem foto cadastrada ───
Widget _semFotoServico({double height = 280}) {
  return Container(
    height: height,
    width: double.infinity,
    color: const Color(0xFFB7D5B0),
    alignment: Alignment.center,
    child: Image.asset(
      'assets/images/mutuoLogo.png',
      width: height * 0.4,
      height: height * 0.4,
      fit: BoxFit.contain,
    ),
  );
}

// ─── NAV ITEM AUXILIAR ────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;

  _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
  });
}
