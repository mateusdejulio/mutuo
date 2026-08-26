import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mutuo/inicialOng.dart';
import 'package:mutuo/inicialOng.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/planosOng.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:mutuo/widgets/modal_atividade_ong.dart';
import 'package:mutuo/servicosOng.dart';
import 'package:mutuo/services/auth_service.dart';

class PerfilOng extends StatefulWidget {
  final String cnpj;
  final String nomeInicial;

  const PerfilOng({super.key, required this.cnpj, this.nomeInicial = ''});

  @override
  State<PerfilOng> createState() => _PerfilOngState();
}

class _PerfilOngState extends State<PerfilOng> {
  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;
  static const _cinzaTexto = Color(0xFF6B705C);

  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _carregando = true;
  bool _carregandoAtividades = true;
  bool _editando = false;
  bool _salvando = false;
  bool _enviandoFoto = false;

  Map<String, dynamic>? _ong;
  List<dynamic> _atividades = [];
  List<dynamic> _solicitacoes = [];
  String? _fotoUrl;

  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();

  int _bottomNavIndex = -1; // perfil não faz parte das abas fixas

  static const List<String> _focosServico = [
    'Culinária',
    'Jardinagem',
    'Música',
    'Tecnologia',
    'Educação',
    'Animais',
    'Idosos',
    'Ambiental',
    'Outro',
  ];

  @override
  void initState() {
    super.initState();
    _carregarOng();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    super.dispose();
  }

  String get _inicial {
    final nome = _ong?['nomeOng']?.toString() ?? widget.nomeInicial;
    return nome.isNotEmpty ? nome[0].toUpperCase() : 'O';
  }

  // Plano gratuito: até 3 atividades ativas. ONGs premium (campo `premium`
  // vindo do banco) não têm esse limite.
  bool get _limiteAtingido =>
      (_ong?['premium'] != 1) && _atividades.length >= 3;

  // handle "@..." só pra exibição — não existe campo de usuário/handle
  // no banco pra ONG, então derivo a partir do nome.
  String get _handle {
    final nome = _ong?['nomeOng']?.toString() ?? widget.nomeInicial;
    final semAcento = nome
        .toLowerCase()
        .replaceAll(RegExp(r'[áàãâ]'), 'a')
        .replaceAll(RegExp(r'[éê]'), 'e')
        .replaceAll('í', 'i')
        .replaceAll(RegExp(r'[óõô]'), 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
    final slug = semAcento.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '@$slug';
  }

  String _tempoNoMutuo(String? cadastro) {
    if (cadastro == null || cadastro.isEmpty) return '-';
    final data = DateTime.tryParse(cadastro);
    if (data == null) return '-';
    final dias = DateTime.now().difference(data).inDays;
    if (dias < 30) return '$dias dias';
    if (dias < 365) return '${(dias / 30).floor()} meses';
    return '${(dias / 365).floor()} anos';
  }

  String _dataFormatada(String? cadastro) {
    if (cadastro == null || cadastro.isEmpty) return '-';
    final data = DateTime.tryParse(cadastro);
    if (data == null) return '-';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Future<void> _carregarOng() async {
    setState(() => _carregando = true);

    final resultados = await Future.wait([
      _api.buscarOngPorCnpj(widget.cnpj),
      _api.buscarFotoPerfilOng(widget.cnpj),
    ]);

    final dados = resultados[0] as Map<String, dynamic>?;
    final foto = resultados[1] as String?;

    if (!mounted) return;
    setState(() {
      _ong = dados;
      _fotoUrl = foto;
      _nomeCtrl.text = dados?['nomeOng']?.toString() ?? widget.nomeInicial;
      _emailCtrl.text = dados?['email']?.toString() ?? '';
      _telefoneCtrl.text = dados?['telefone']?.toString() ?? '';
      _carregando = false;
    });

    _carregarAtividades();
    _carregarSolicitacoes();
  }

  Future<void> _carregarAtividades() async {
    setState(() => _carregandoAtividades = true);
    final lista = await _api.buscarServicosOng(widget.cnpj);
    if (!mounted) return;
    setState(() {
      _atividades = lista;
      _carregandoAtividades = false;
    });
  }

  Future<void> _carregarSolicitacoes() async {
    final lista = await _api.buscarSolicitacoesOng(widget.cnpj);
    if (!mounted) return;
    setState(() => _solicitacoes = lista);
  }

  Future<void> _salvarEdicao() async {
    setState(() => _salvando = true);

    final resultado = await _api.atualizarOng(widget.cnpj, {
      'nomeOng': _nomeCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'telefone': _telefoneCtrl.text.trim(),
    });

    if (!mounted) return;
    setState(() => _salvando = false);

    if (resultado['sucesso'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado['erro'] ??
                resultado['mensagem'] ??
                'Não foi possível salvar as alterações.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _ong ??= {};
      _ong!['nomeOng'] = _nomeCtrl.text.trim();
      _ong!['email'] = _emailCtrl.text.trim();
      _ong!['telefone'] = _telefoneCtrl.text.trim();
      _editando = false;
    });
  }

  Future<void> _trocarFoto() async {
    final imagem = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (imagem == null) return;

    setState(() => _enviandoFoto = true);
    final bytes = await imagem.readAsBytes();
    final resultado = await _api.enviarFotoPerfilOng(
      widget.cnpj,
      bytes,
      imagem.name,
    );
    if (!mounted) return;
    setState(() => _enviandoFoto = false);

    if (resultado['sucesso'] == true) {
      setState(() => _fotoUrl = resultado['fotoPerfil']?.toString());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado['erro']?.toString() ??
                'Não foi possível atualizar a foto.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _excluirAtividade(String id, int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Excluir atividade',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Tem certeza que deseja excluir esta atividade?',
          style: GoogleFonts.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.quicksand(color: _cinzaTexto),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Excluir',
              style: GoogleFonts.quicksand(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final resultado = await _api.excluirServicoOng(id);
    if (!mounted) return;

    if (resultado['sucesso'] == false && resultado['erro'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultado['erro'])));
      return;
    }

    setState(() => _atividades.removeAt(index));
  }

  Widget _avatarCircle({required double size}) {
    final foto = _fotoUrl;
    if (foto == null || foto.isEmpty) return _avatarIniciais(size: size);
    return ClipOval(
      child: Image.network(
        '${ApiService.baseUrl}$foto',
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _avatarIniciais(size: size),
        errorBuilder: (context, error, stack) => _avatarIniciais(size: size),
      ),
    );
  }

  Widget _avatarIniciais({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: _bege, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        _inicial,
        style: GoogleFonts.quicksand(
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
          color: _verde,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator(color: _verde))
            : RefreshIndicator(
                color: _verde,
                onRefresh: _carregarOng,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _cardTopo(),
                            const SizedBox(height: 18),
                            _cardDados(),
                            const SizedBox(height: 18),
                            _cardPontos(),
                            const SizedBox(height: 18),
                            _cardAtividades(),
                            const SizedBox(height: 18),
                            _cardSolicitacoes(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _header() {
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
          IconButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 250),
                  pageBuilder: (_, __, ___) => InicialOng(
                    nome: _ong?['nomeOng'] ?? widget.nomeInicial,
                    cnpj: widget.cnpj,
                  ),
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                ),
              );
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _branco,
              size: 18,
            ),
          ),
          Text(
            'Meu Perfil',
            style: GoogleFonts.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _branco,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await AuthService.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const Login()),
                  (route) => false,
                );
              }
            },
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 18, color: _verde),
                    const SizedBox(width: 8),
                    Text(
                      'Sair',
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            child: _avatarCircle(size: 36),
          ),
        ],
      ),
    );
  }

  Widget _cardTopo() {
    final nome = _ong?['nomeOng']?.toString() ?? widget.nomeInicial;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0DDD8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  _avatarCircle(size: 64),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _enviandoFoto ? null : _trocarFoto,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: _verde,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: _enviandoFoto
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _branco,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_outlined,
                                size: 13,
                                color: _branco,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome.isNotEmpty ? nome : 'ONG',
                      style: GoogleFonts.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A2E1B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _handle,
                      style: GoogleFonts.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9AAB96),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF0F4EF)),
          const SizedBox(height: 12),
          Row(
            children: [
              _statTopo('${_atividades.length}', 'Atividades ativas'),
              _divisorVertical(),
              // Sem coluna de avaliação positiva/negativa pra ONG no banco ainda.
              _statTopo('—', 'Avaliações positivas'),
              _divisorVertical(),
              _statTopo(
                _tempoNoMutuo(_ong?['cadastro']?.toString()),
                'No Mútuo',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divisorVertical() =>
      Container(width: 1, height: 30, color: const Color(0xFFF0F4EF));

  Widget _statTopo(String valor, String texto) {
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: GoogleFonts.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _verde,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9AAB96),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardDados() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0DDD8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dados do usuário',
                      style: GoogleFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _verde,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Informações pessoais e preferências',
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9AAB96),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _editando = !_editando),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _bege,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _editando ? Icons.close : Icons.edit_outlined,
                        size: 14,
                        color: _verde,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _editando ? 'Cancelar' : 'Editar perfil',
                        style: GoogleFonts.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _verde,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_editando) ...[
            _campoEdicao('Nome da ONG', _nomeCtrl),
            const SizedBox(height: 12),
            _campoEdicao('E-mail', _emailCtrl),
            const SizedBox(height: 12),
            _campoEdicao('Telefone', _telefoneCtrl),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verde,
                  foregroundColor: _branco,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _salvando ? null : _salvarEdicao,
                child: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _branco,
                        ),
                      )
                    : Text(
                        'Salvar alterações',
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ] else ...[
            _linhaInfo(
              Icons.mail_outline_rounded,
              _ong?['email']?.toString() ?? '-',
            ),
            const SizedBox(height: 12),
            _linhaInfo(
              Icons.phone_outlined,
              _ong?['telefone']?.toString() ?? '-',
            ),
            const SizedBox(height: 12),
            _linhaInfo(
              Icons.calendar_today_outlined,
              'Membro desde ${_dataFormatada(_ong?['cadastro']?.toString())}',
            ),
            const SizedBox(height: 12),
            _linhaInfo(
              Icons.diamond_outlined,
              _ong?['premium'] == 1 ? 'Plano Premium' : 'Plano gratuito',
            ),
          ],
        ],
      ),
    );
  }

  Widget _campoEdicao(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _linhaInfo(IconData icone, String texto) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _verde.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, size: 16, color: _verde),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: GoogleFonts.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF344E41),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardPontos() {
    final pontos = _ong?['pontos'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _verde,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            pontos != null ? '$pontos' : '0',
            style: GoogleFonts.quicksand(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: _branco,
            ),
          ),
          Text(
            'Pontos disponíveis',
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: _branco.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardAtividades() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0DDD8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Minhas atividades',
                      style: GoogleFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _verde,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Atividades que sua ONG oferece',
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9AAB96),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _limiteAtingido
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlanosOng(
                            cnpj: widget.cnpj,
                            nomeInicial: widget.nomeInicial,
                          ),
                        ),
                      )
                    : () => abrirModalAtividadeOng(
                        context: context,
                        cnpj: widget.cnpj,
                        onSucesso: _carregarAtividades,
                        totalAtividades: _atividades.length,
                        ongPremium: _ong?['premium'] == 1,
                      ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _limiteAtingido ? Colors.redAccent : _verde,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _limiteAtingido
                            ? Icons.workspace_premium_outlined
                            : Icons.add,
                        size: 14,
                        color: _branco,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _limiteAtingido ? 'Ver planos' : 'Adicionar',
                        style: GoogleFonts.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _branco,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_limiteAtingido) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Limite de 3 atividades do plano gratuito consumido. Faça upgrade pra cadastrar mais.',
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_carregandoAtividades)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: CircularProgressIndicator(color: _verde)),
            )
          else if (_atividades.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'Você ainda não cadastrou nenhuma atividade.',
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  color: const Color(0xFF9AAB96),
                ),
              ),
            )
          else
            ..._atividades
                .whereType<Map<String, dynamic>>()
                .toList()
                .asMap()
                .entries
                .map((entry) {
                  final index = entry.key;
                  final atividade = entry.value;
                  return _linhaAtividade(atividade, index);
                }),
        ],
      ),
    );
  }

  Widget _linhaAtividade(Map<String, dynamic> atividade, int index) {
    final nome = atividade['nomeServico']?.toString() ?? 'Atividade sem nome';
    final descricao = atividade['descricao']?.toString() ?? '';
    final id = atividade['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4EBE2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A2E1B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    color: const Color(0xFF6B705C),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => abrirModalAtividadeOng(
              context: context,
              cnpj: widget.cnpj,
              atividade: atividade,
              onSucesso: _carregarAtividades,
              totalAtividades: _atividades.length,
              ongPremium: _ong?['premium'] == 1,
            ),
            icon: const Icon(Icons.edit_outlined, color: _verdeMedio, size: 20),
          ),
          IconButton(
            onPressed: () => _excluirAtividade(id, index),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardSolicitacoes() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _branco,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0DDD8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Solicitações recebidas',
            style: GoogleFonts.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _verde,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Voluntários interessados nas suas atividades',
            style: GoogleFonts.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9AAB96),
            ),
          ),
          if (_solicitacoes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'Nenhuma solicitação recebida ainda.',
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  color: const Color(0xFF9AAB96),
                ),
              ),
            )
          else
            ..._solicitacoes.whereType<Map<String, dynamic>>().map(
              (s) => _linhaSolicitacao(s),
            ),
        ],
      ),
    );
  }

  Widget _linhaSolicitacao(Map<String, dynamic> s) {
    final nomeSolicitador = s['nomeSolicitador']?.toString() ?? 'Voluntário';
    final nomeServico = s['nomeServico']?.toString() ?? '';
    final status = s['statusSolicitacao']?.toString() ?? 'Pendente';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4EBE2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nomeSolicitador,
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A2E1B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  nomeServico,
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    color: const Color(0xFF6B705C),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _bege,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: GoogleFonts.quicksand(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _verde,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final navItems = [
      _NavItemPerfilOng(
        icon: Icons.home_rounded,
        outlinedIcon: Icons.home_outlined,
        label: 'Início',
        onTap: () {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 250),
              pageBuilder: (_, __, ___) => InicialOng(
                nome: _ong?['nomeOng'] ?? widget.nomeInicial,
                cnpj: widget.cnpj,
              ),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        },
      ),
      _NavItemPerfilOng(
        icon: Icons.volunteer_activism_rounded,
        outlinedIcon: Icons.volunteer_activism_outlined,
        label: 'Atividades',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServicosOng(
                nome: _ong?['nomeOng'] ?? widget.nomeInicial,
                cnpj: widget.cnpj,
              ),
            ),
          );
        },
      ),
      _NavItemPerfilOng(
        icon: Icons.assignment_turned_in_rounded,
        outlinedIcon: Icons.assignment_turned_in_outlined,
        label: 'Solicitações',
        onTap: null,
      ),
      _NavItemPerfilOng(
        icon: Icons.chat_bubble_rounded,
        outlinedIcon: Icons.chat_bubble_outline_rounded,
        label: 'Chat',
        onTap: null,
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
          currentIndex: _bottomNavIndex < 0 ? 0 : _bottomNavIndex,
          onTap: (index) {
            final item = navItems[index];
            if (item.onTap != null) {
              item.onTap!();
            } else {
              setState(() => _bottomNavIndex = index);
            }
          },
          backgroundColor: _branco,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedItemColor: _bottomNavIndex < 0
              ? const Color(0xFF9AAB96)
              : _verde,
          unselectedItemColor: const Color(0xFF9AAB96),
          selectedLabelStyle: GoogleFonts.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          items: List.generate(navItems.length, (index) {
            final item = navItems[index];
            final isSelected = _bottomNavIndex == index;
            return BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(
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

class _NavItemPerfilOng {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final VoidCallback? onTap;

  _NavItemPerfilOng({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    this.onTap,
  });
}
