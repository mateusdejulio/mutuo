import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mutuo/login.dart';
import 'package:mutuo/ongs.dart';
import 'package:mutuo/servicos.dart';
import 'package:mutuo/quem_somos.dart';
import 'package:mutuo/planosUsuario.dart';
import 'package:mutuo/services/api_service.dart';
import 'package:image_picker/image_picker.dart';

// ─── DATA CLASS PARA HISTÓRICO (dados de exemplo, ligue à sua API quando tiver a rota) ───
class _ItemHistorico {
  final String titulo;
  final String participante;
  final double? estrelas;
  final String? comentario;
  final String data;
  final int pontos;
  final bool positivo;
  final bool aguardandoConfirmacao;

  _ItemHistorico({
    required this.titulo,
    required this.participante,
    this.estrelas,
    this.comentario,
    required this.data,
    this.pontos = 0,
    this.positivo = true,
    this.aguardandoConfirmacao = false,
  });
}

class PerfilUsuario extends StatefulWidget {
  final String cpf;
  final String nomeInicial;

  const PerfilUsuario({super.key, required this.cpf, this.nomeInicial = ''});

  @override
  State<PerfilUsuario> createState() => _PerfilUsuarioState();
}

class _PerfilUsuarioState extends State<PerfilUsuario> {
  // ─── Paleta (mesma do resto do app) ───────────────────────
  static const _verde = Color(0xFF3A5A40);
  static const _verdeMedio = Color(0xFF588157);
  static const _bege = Color(0xFFDAD7CD);
  static const _fundo = Color(0xFFEDEAE5);
  static const _branco = Colors.white;
  static const _cinzaTexto = Color(0xFF6B705C);

  final ApiService _api = ApiService();

  bool _carregando = true;
  bool _carregandoServicos = true;
  bool _editando = false;
  bool _salvando = false;

  Map<String, dynamic>? _usuario;
  List<dynamic> _servicos = [];
  String? _fotoUrl;
  bool _enviandoFoto = false;
  final ImagePicker _picker = ImagePicker();

  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();

  int _bottomNavIndex = -1; // perfil não faz parte das 4 abas fixas
  String _filtroHistorico = 'prestados';

  // ─── Opções de foco disponíveis no cadastro de serviço ─────
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

  final List<_ItemHistorico> _prestados = [
    _ItemHistorico(
      titulo: 'Aula de yoga',
      participante: 'Cliente: João Silva',
      estrelas: 5,
      comentario: 'Excelente professora! Muito atenciosa e paciente.',
      data: '15 out 2025',
      pontos: 150,
      positivo: true,
    ),
  ];
  final List<_ItemHistorico> _utilizados = [
    _ItemHistorico(
      titulo: 'Aula de violão',
      participante: 'Prestador: Marcos Lima',
      estrelas: 5,
      comentario: 'Aula incrível, aprendi muito!',
      data: '15 out 2025',
      pontos: 150,
      positivo: false,
    ),
  ];
  final List<_ItemHistorico> _confirmar = [
    _ItemHistorico(
      titulo: 'Aula de violão',
      participante: 'Prestador: Marcos Lima',
      data: '12 nov 2025',
      aguardandoConfirmacao: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    super.dispose();
  }

    // ─── inicial segura pro avatar (mesmo padrão usado no resto do app) ───
  String get _inicial {
    final nome = _usuario?['nome']?.toString() ?? widget.nomeInicial;
    return nome.isNotEmpty ? nome[0].toUpperCase() : 'U';
  }

  // Plano gratuito: até 3 serviços ativos. Usuários premium (campo `premium`
  // vindo do banco) podem cadastrar até 8 — limite já aplicado no backend
  // (rota POST /servicos).
  bool get _limiteAtingido =>
      (_usuario?['premium'] != 1) && _servicos.length >= 3;

  Future<void> _carregarUsuario() async {
    setState(() => _carregando = true);

    final resultados = await Future.wait([
      _api.buscarUsuarioPorCpf(widget.cpf),
      _api.buscarFotoPerfil(widget.cpf),
    ]);

    final dados = resultados[0] as Map<String, dynamic>?;
    final foto = resultados[1] as String?;

    if (!mounted) return;
    setState(() {
      _usuario = dados;
      _fotoUrl = foto;
      _nomeCtrl.text = dados?['nome']?.toString() ?? widget.nomeInicial;
      _emailCtrl.text = dados?['email']?.toString() ?? '';
      _telefoneCtrl.text = dados?['telefone']?.toString() ?? '';
      _carregando = false;
    });
    _carregarServicos();
  }

  Future<void> _carregarServicos() async {
    setState(() => _carregandoServicos = true);
    final lista = await _api.buscarServicosDoUsuario(widget.cpf);
    if (!mounted) return;
    setState(() {
      _servicos = lista;
      _carregandoServicos = false;
    });
  }

  Future<void> _salvarEdicao() async {
    setState(() => _salvando = true);

    final resultado = await _api.atualizarUsuario(widget.cpf, {
      'nome': _nomeCtrl.text.trim(),
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
      _usuario ??= {};
      _usuario!['nome'] = _nomeCtrl.text.trim();
      _usuario!['email'] = _emailCtrl.text.trim();
      _usuario!['telefone'] = _telefoneCtrl.text.trim();
      _editando = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil atualizado com sucesso!')),
    );
  }

  void _cancelarEdicao() {
    setState(() {
      _nomeCtrl.text = _usuario?['nome']?.toString() ?? '';
      _emailCtrl.text = _usuario?['email']?.toString() ?? '';
      _telefoneCtrl.text = _usuario?['telefone']?.toString() ?? '';
      _editando = false;
    });
  }

  Future<void> _trocarFoto() async {
    final XFile? imagem = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (imagem == null) return;

    setState(() => _enviandoFoto = true);

    final bytes = await imagem.readAsBytes();
    final resultado = await _api.enviarFotoPerfil(
      widget.cpf,
      bytes,
      imagem.name,
    );

    if (!mounted) return;
    setState(() => _enviandoFoto = false);

    if (resultado['sucesso'] == true) {
      setState(() => _fotoUrl = resultado['fotoPerfil']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil atualizada!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado['erro'] ?? 'Não foi possível atualizar a foto.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _excluirServico(String id, int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Excluir serviço',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Tem certeza que deseja excluir este serviço?',
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

    final resultado = await _api.excluirServico(id);
    if (!mounted) return;

    if (resultado['sucesso'] == false && resultado['erro'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultado['erro'])));
      return;
    }

    setState(() => _servicos.removeAt(index));
  }

  // ─── Modal de "Adicionar/Editar serviço" (bottom sheet) ─────
  // Se `servico` for passado, o modal abre em modo de edição, com os
  // campos já preenchidos. Se for null, abre em modo de cadastro novo.
  void _abrirModalServico({Map<String, dynamic>? servico}) {
    final editando = servico != null;

    final nomeCtrl = TextEditingController(
      text: servico?['nomeServico']?.toString() ?? '',
    );
    final descCtrl = TextEditingController(
      text: servico?['descricao']?.toString() ?? '',
    );
    final duracaoCtrl = TextEditingController(
      text:
          servico?['horas']?.toString() ??
          servico?['duracao']?.toString() ??
          '',
    );

    // Normaliza o foco vindo do banco (evita mismatch de maiúscula/acento
    // com a lista fixa) e garante que o valor atual sempre exista na lista.
    String? focoSelecionado = servico?['foco']?.toString();
    if (focoSelecionado != null) {
      focoSelecionado = _focosServico.firstWhere(
        (f) => f.toLowerCase() == focoSelecionado!.toLowerCase(),
        orElse: () => focoSelecionado!,
      );
    }
    final focosDisponiveis = List<String>.from(_focosServico);
    if (focoSelecionado != null &&
        !focosDisponiveis.contains(focoSelecionado)) {
      focosDisponiveis.add(focoSelecionado);
    }

    XFile? imagemSelecionada;
    bool enviando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> escolherImagem() async {
              final XFile? imagem = await _picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1024,
                imageQuality: 85,
              );
              if (imagem != null) {
                setModalState(() => imagemSelecionada = imagem);
              }
            }

            Future<void> confirmar() async {
              if (nomeCtrl.text.trim().isEmpty ||
                  descCtrl.text.trim().isEmpty ||
                  focoSelecionado == null ||
                  duracaoCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  const SnackBar(
                    content: Text('Preencha todos os campos obrigatórios.'),
                  ),
                );
                return;
              }

              setModalState(() => enviando = true);

              List<int>? bytes;
              String? nomeArquivo;
              if (imagemSelecionada != null) {
                bytes = await imagemSelecionada!.readAsBytes();
                nomeArquivo = imagemSelecionada!.name;
              }

              final resultado = editando
                  ? await _api.atualizarServico(
                      id: servico!['id'].toString(),
                      nomeServico: nomeCtrl.text.trim(),
                      descricao: descCtrl.text.trim(),
                      foco: focoSelecionado!,
                      duracao: duracaoCtrl.text.trim(),
                      imagemBytes: bytes,
                      imagemNome: nomeArquivo,
                    )
                  : await _api.cadastrarServico(
                      cpf: widget.cpf,
                      nomeServico: nomeCtrl.text.trim(),
                      descricao: descCtrl.text.trim(),
                      foco: focoSelecionado!,
                      duracao: duracaoCtrl.text.trim(),
                      imagemBytes: bytes,
                      imagemNome: nomeArquivo,
                    );

              setModalState(() => enviando = false);

              if (resultado['sucesso'] == true) {
                if (!mounted) return;
                Navigator.pop(modalContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      editando
                          ? 'Serviço atualizado com sucesso!'
                          : 'Serviço cadastrado com sucesso!',
                    ),
                  ),
                );
                _carregarServicos();
              } else {
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      resultado['erro']?.toString() ??
                          (editando
                              ? 'Não foi possível atualizar o serviço.'
                              : 'Não foi possível cadastrar o serviço.'),
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalContext).size.height * 0.9,
                ),
                decoration: const BoxDecoration(
                  color: _verde,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE5E2D8),
                            ),
                            child: ClipOval(
                              child: Image.asset('assets/images/logo.png'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              editando
                                  ? 'Editar serviço'
                                  : 'Cadastro de serviço',
                              style: GoogleFonts.quicksand(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      _modalLabel('Nome do serviço', Icons.badge_outlined),
                      _modalInput(
                        controller: nomeCtrl,
                        hint: 'Ex: Aula de matemática',
                      ),

                      const SizedBox(height: 16),

                      _modalLabel('Descrição', Icons.notes_rounded),
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        child: TextField(
                          controller: descCtrl,
                          maxLines: 4,
                          maxLength: 150,
                          onChanged: (_) => setModalState(() {}),
                          style: GoogleFonts.quicksand(
                            fontSize: 13,
                            color: const Color(0xFF344E41),
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Descreva o serviço, público-alvo e objetivos...',
                            hintStyle: GoogleFonts.quicksand(
                              fontSize: 12,
                              color: const Color(0xFF9E9E9E),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFE5E2D8),
                            counterStyle: GoogleFonts.quicksand(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _modalLabel(
                                  'Foco',
                                  Icons.label_outline_rounded,
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 5),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5E2D8),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: focoSelecionado,
                                      isExpanded: true,
                                      hint: Text(
                                        'Selecionar',
                                        style: GoogleFonts.quicksand(
                                          fontSize: 13,
                                          color: const Color(0xFF6B705C),
                                        ),
                                      ),
                                      items: focosDisponiveis
                                          .map(
                                            (f) => DropdownMenuItem(
                                              value: f,
                                              child: Text(
                                                f,
                                                style: GoogleFonts.quicksand(
                                                  fontSize: 13,
                                                  color: const Color(
                                                    0xFF344E41,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setModalState(
                                        () => focoSelecionado = v,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _modalLabel(
                                  'Duração',
                                  Icons.access_time_rounded,
                                ),
                                _modalInput(
                                  controller: duracaoCtrl,
                                  hint: 'Ex: 2 horas',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 18),

                      _modalLabel('Imagem do serviço', Icons.image_outlined),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: escolherImagem,
                              child: Container(
                                height: 90,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white54,
                                    width: 1.4,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.file_upload_outlined,
                                        color: Colors.white70,
                                        size: 26,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        editando && imagemSelecionada == null
                                            ? 'Trocar imagem'
                                            : 'Clique para enviar',
                                        style: GoogleFonts.quicksand(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (imagemSelecionada != null) ...[
                            const SizedBox(width: 12),
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: kIsWeb
                                      ? Image.network(
                                          imagemSelecionada!.path,
                                          width: 76,
                                          height: 76,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(imagemSelecionada!.path),
                                          width: 76,
                                          height: 76,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: escolherImagem,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: _verdeMedio,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (editando &&
                              (servico['imagem']?.toString().isNotEmpty ??
                                  false)) ...[
                            const SizedBox(width: 12),
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    '${ApiService.baseUrl}${servico['imagem']}',
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: escolherImagem,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: _verdeMedio,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 26),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: enviando ? null : confirmar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _verdeMedio,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: enviando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            enviando
                                ? 'Enviando...'
                                : (editando
                                      ? 'Salvar alterações'
                                      : 'Confirmar cadastro'),
                            style: GoogleFonts.quicksand(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Center(
                        child: TextButton(
                          onPressed: enviando
                              ? null
                              : () => Navigator.pop(modalContext),
                          child: Text(
                            'Cancelar',
                            style: GoogleFonts.quicksand(color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _modalLabel(String texto, IconData icone) {
    return Row(
      children: [
        Icon(icone, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Text(
          texto,
          style: GoogleFonts.quicksand(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _modalInput({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      child: TextField(
        controller: controller,
        style: GoogleFonts.quicksand(
          fontSize: 13,
          color: const Color(0xFF344E41),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.quicksand(
            fontSize: 12,
            color: const Color(0xFF9E9E9E),
          ),
          filled: true,
          fillColor: const Color(0xFFE5E2D8),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ─── formata "membro desde" sem depender de pacote intl ───
  String _formatarMesAno(String? isoData) {
    if (isoData == null || isoData.isEmpty) return '—';
    try {
      final data = DateTime.parse(isoData);
      const meses = [
        'janeiro',
        'fevereiro',
        'março',
        'abril',
        'maio',
        'junho',
        'julho',
        'agosto',
        'setembro',
        'outubro',
        'novembro',
        'dezembro',
      ];
      return '${meses[data.month - 1]} de ${data.year}';
    } catch (e) {
      return '—';
    }
  }

  String _tempoNoMutuo(String? isoData) {
    if (isoData == null || isoData.isEmpty) return '—';
    try {
      final data = DateTime.parse(isoData);
      final meses = DateTime.now().difference(data).inDays ~/ 30;
      if (meses < 1) return '< 1 mês';
      if (meses == 1) return '1 mês';
      return '$meses meses';
    } catch (e) {
      return '—';
    }
  }

  void _irParaInicio() => Navigator.pop(context);

  void _irParaServicos() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => Servicos(
          nome: _usuario?['nome'] ?? widget.nomeInicial,
          cpf: widget.cpf,
          initialNavIndex: 1,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _irParaOngs() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => Ongs(
          nome: _usuario?['nome'] ?? widget.nomeInicial,
          cpf: widget.cpf,
          initialNavIndex: 2,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  // ─── AVATAR (foto de perfil com fallback pra iniciais) ─────
  // Usado no header e no card topo. Sem edição por enquanto —
  // só exibição. Se a foto falhar ao carregar, cai pras iniciais.
  Widget _avatarCircle({required double size}) {
    final foto = _fotoUrl;
    if (foto == null || foto.isEmpty) {
      return _avatarIniciais(size: size);
    }
    return ClipOval(
      child: Image.network(
        '${ApiService.baseUrl}$foto',
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _avatarIniciais(size: size);
        },
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
                onRefresh: () async {
                  await _carregarUsuario();
                },
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
                            _cardServicos(),
                            const SizedBox(height: 18),
                            _cardHistorico(),
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

  // ─── HEADER (padronizado com inicialUser.dart) ────────────
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
            onPressed: () => Navigator.pop(context),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _verdeMedio.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: _branco,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const Login()),
                  (route) => false,
                );
              } else if (value == 'quem_somos') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuemSomos(
                      nome: _usuario?['nome'] ?? widget.nomeInicial,
                      cpf: widget.cpf,
                    ),
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
                value: 'quem_somos',
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: _verde),
                    const SizedBox(width: 8),
                    Text(
                      'Quem somos',
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
                      'Sair',
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            child: _avatarCircle(size: 40),
          ),
        ],
      ),
    );
  }

  // ─── CARD TOPO (foto + nome + estatísticas) ───────────────
  Widget _cardTopo() {
    final nome = _usuario?['nome']?.toString() ?? widget.nomeInicial;
    final email = _usuario?['email']?.toString() ?? '';

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
              GestureDetector(
                onTap: _enviandoFoto ? null : _trocarFoto,
                child: Stack(
                  children: [
                    _avatarCircle(size: 68),
                    if (_enviandoFoto)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _verdeMedio,
                          shape: BoxShape.circle,
                          border: Border.all(color: _branco, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome.isNotEmpty ? nome : 'Usuário',
                      style: GoogleFonts.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A2E1B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
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
              _statTopo('${_servicos.length}', 'Serviços ativos'),
              _divisorVertical(),
              _statTopo('${_usuario?['pontos'] ?? 0}', 'Pontos'),
              _divisorVertical(),
              _statTopo(
                _tempoNoMutuo(_usuario?['cadastro']?.toString()),
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

  // ─── CARD DADOS DO USUÁRIO (com edição) ───────────────────
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              if (!_editando)
                GestureDetector(
                  onTap: () => setState(() => _editando = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2E6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_rounded, size: 14, color: _verde),
                        const SizedBox(width: 6),
                        Text(
                          'Editar',
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
            _campoEdicao(
              label: 'Nome completo',
              icon: Icons.person_outline_rounded,
              controller: _nomeCtrl,
            ),
            const SizedBox(height: 12),
            _campoEdicao(
              label: 'E-mail',
              icon: Icons.email_outlined,
              controller: _emailCtrl,
              tipo: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _campoEdicao(
              label: 'Telefone',
              icon: Icons.phone_outlined,
              controller: _telefoneCtrl,
              tipo: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _campoSomenteLeitura(
              Icons.calendar_today_rounded,
              'Membro desde ${_formatarMesAno(_usuario?['cadastro']?.toString())}',
            ),
            const SizedBox(height: 8),
                        _campoSomenteLeitura(
              Icons.workspace_premium_rounded,
              _usuario?['premium'] == 1 ? 'Plano Premium' : 'Plano gratuito',
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _salvando ? null : _cancelarEdicao,
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.quicksand(
                      fontWeight: FontWeight.w700,
                      color: _cinzaTexto,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _salvando ? null : _salvarEdicao,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verde,
                    foregroundColor: _branco,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
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
              ],
            ),
          ] else ...[
            _itemInfo(
              Icons.email_outlined,
              _usuario?['email']?.toString() ?? '—',
            ),
            const SizedBox(height: 12),
            _itemInfo(
              Icons.phone_outlined,
              _usuario?['telefone']?.toString() ?? '—',
            ),
            const SizedBox(height: 12),
            _itemInfo(
              Icons.calendar_today_rounded,
              'Membro desde ${_formatarMesAno(_usuario?['cadastro']?.toString())}',
              esmaecido: true,
            ),
            const SizedBox(height: 12),
                       _itemInfo(
              Icons.workspace_premium_rounded,
              _usuario?['premium'] == 1 ? 'Plano Premium' : 'Plano gratuito',
              esmaecido: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemInfo(IconData icon, String texto, {bool esmaecido = false}) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2E6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: _verdeMedio),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: GoogleFonts.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: esmaecido
                  ? const Color(0xFF999999)
                  : const Color(0xFF3A4A3B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoSomenteLeitura(IconData icon, String texto) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF999999)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: GoogleFonts.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF999999),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDDDDD)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Fixo',
            style: GoogleFonts.quicksand(
              fontSize: 10,
              color: const Color(0xFF999999),
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoEdicao({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType tipo = TextInputType.text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2E6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: _verdeMedio),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: tipo,
            style: GoogleFonts.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: label,
              hintStyle: GoogleFonts.quicksand(
                fontSize: 12,
                color: const Color(0xFFAAAAAA),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _verdeMedio),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── CARD PONTOS ───────────────────────────────────────────
  Widget _cardPontos() {
    final pontos = _usuario?['pontos'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_verdeMedio, _verde],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _verde.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saldo de pontos',
                style: GoogleFonts.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pontos != null ? '$pontos' : '0',
            style: GoogleFonts.quicksand(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            'Pontos disponíveis',
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CARD MEUS SERVIÇOS ────────────────────────────────────
  Widget _cardServicos() {
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
                      'Meus serviços',
                      style: GoogleFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _verde,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Serviços que você oferece',
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
                          builder: (_) => PlanosUsuario(
                            cpf: widget.cpf,
                            nomeInicial: widget.nomeInicial,
                          ),
                        ),
                      )
                    : () => _abrirModalServico(),
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
                    children: [
                      Icon(
                        _limiteAtingido
                            ? Icons.workspace_premium_outlined
                            : Icons.add_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _limiteAtingido ? 'Ver planos' : 'Adicionar',
                        style: GoogleFonts.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
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
                      'Limite de 3 serviços do plano gratuito consumido. Assine o Premium pra cadastrar até 8.',
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
          const SizedBox(height: 16),
          if (_carregandoServicos)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: _verde)),
            )
          else if (_servicos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Você ainda não cadastrou nenhum serviço.',
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    color: const Color(0xFF9AAB96),
                  ),
                ),
              ),
            )
          else
            ..._servicos.asMap().entries.map(
              (entry) => _cardServicoItem(entry.value, entry.key),
            ),
        ],
      ),
    );
  }

  Widget _cardServicoItem(dynamic servico, int index) {
    final nome = servico['nomeServico']?.toString() ?? 'Serviço sem nome';
    final descricao = servico['descricao']?.toString() ?? '';
    final ativo = servico['ativo'] == null
        ? true
        : (servico['ativo'] == true || servico['ativo'] == 1);
    final nota = servico['nota'] != null
        ? double.tryParse(servico['nota'].toString())?.toStringAsFixed(1) ?? '—'
        : '—';
    final avaliacoes = servico['avaliacoes'] ?? 0;
    final pontos = servico['pontos'] ?? 0;
    final id = servico['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4EBE2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nome,
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A2E1B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ativo
                      ? const Color(0xFFE6F4EA)
                      : const Color(0xFFF4F4F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ativo ? 'Ativo' : 'Inativo',
                  style: GoogleFonts.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: ativo
                        ? const Color(0xFF2D6A4F)
                        : const Color(0xFF999999),
                  ),
                ),
              ),
            ],
          ),
          if (descricao.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              descricao,
              style: GoogleFonts.quicksand(
                fontSize: 12,
                color: const Color(0xFF7A8C76),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: Color(0xFFF5A623),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$nota ($avaliacoes)',
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7A8C76),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, size: 15, color: _verdeMedio),
                  const SizedBox(width: 3),
                  Text(
                    '$pontos pts/hora',
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _verdeMedio,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _abrirModalServico(
                  servico: servico as Map<String, dynamic>,
                ),
                icon: const Icon(Icons.edit_rounded, size: 15, color: _verde),
                label: Text(
                  'Editar',
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _verde,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFEAF2E6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _excluirServico(id, index),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 15,
                  color: Colors.redAccent,
                ),
                label: Text(
                  'Excluir',
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.redAccent,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFDE8E8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── CARD HISTÓRICO ────────────────────────────────────────
  Widget _cardHistorico() {
    final listaAtual = _filtroHistorico == 'prestados'
        ? _prestados
        : _filtroHistorico == 'utilizados'
        ? _utilizados
        : _confirmar;

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
            'Histórico de trocas',
            style: GoogleFonts.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _verde,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Serviços prestados e recebidos',
            style: GoogleFonts.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9AAB96),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filtroChip('prestados', 'Serviços prestados'),
                const SizedBox(width: 8),
                _filtroChip('utilizados', 'Serviços utilizados'),
                const SizedBox(width: 8),
                _filtroChip('confirmar', 'Confirmar serviços'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...listaAtual.map((item) => _itemHistoricoCard(item)),
          if (listaAtual.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Nada por aqui ainda.',
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    color: const Color(0xFF9AAB96),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filtroChip(String valor, String texto) {
    final ativo = _filtroHistorico == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtroHistorico = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: ativo ? _verdeMedio : const Color(0xFFF4F6F3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ativo ? _verdeMedio : const Color(0xFFE4EBE2),
          ),
        ),
        child: Text(
          texto,
          style: GoogleFonts.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ativo ? Colors.white : const Color(0xFF7A8C76),
          ),
        ),
      ),
    );
  }

  Widget _itemHistoricoCard(_ItemHistorico item) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4EBE2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.aguardandoConfirmacao
                  ? const Color(0xFFE8F0FE)
                  : item.positivo
                  ? const Color(0xFFEAF2E6)
                  : const Color(0xFFFFFBE6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.aguardandoConfirmacao
                  ? Icons.history_rounded
                  : item.positivo
                  ? Icons.north_east_rounded
                  : Icons.south_west_rounded,
              size: 16,
              color: item.aguardandoConfirmacao
                  ? const Color(0xFF3A7BBF)
                  : (item.positivo ? _verdeMedio : const Color(0xFFF5A623)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titulo,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A2E1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.participante,
                  style: GoogleFonts.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7A8C76),
                  ),
                ),
                if (item.estrelas != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < item.estrelas!
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 13,
                        color: const Color(0xFFF5A623),
                      ),
                    ),
                  ),
                ],
                if (item.comentario != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"${item.comentario}"',
                    style: GoogleFonts.quicksand(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF4A6A4E),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  item.data,
                  style: GoogleFonts.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB0BFAC),
                  ),
                ),
                if (item.aguardandoConfirmacao) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Em breve: confirmar realização'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 14),
                    label: Text(
                      'Confirmar realização',
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _verdeMedio,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!item.aguardandoConfirmacao)
            Text(
              '${item.positivo ? '+' : '−'}${item.pontos} pts',
              style: GoogleFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: item.positivo ? _verdeMedio : const Color(0xFF9AAB96),
              ),
            ),
        ],
      ),
    );
  }

  // ─── BOTTOM NAV (padronizado com inicialUser.dart) ─────────
  Widget _buildBottomNav() {
    final navItems = [
      _NavItemPerfil(
        icon: Icons.home_rounded,
        outlinedIcon: Icons.home_outlined,
        label: 'Início',
        onTap: _irParaInicio,
      ),
      _NavItemPerfil(
        icon: Icons.work_rounded,
        outlinedIcon: Icons.work_outline_rounded,
        label: 'Serviços',
        onTap: _irParaServicos,
      ),
      _NavItemPerfil(
        icon: Icons.favorite_rounded,
        outlinedIcon: Icons.favorite_border_rounded,
        label: 'ONGs',
        onTap: _irParaOngs,
      ),
      _NavItemPerfil(
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
          // se nenhuma aba estiver "ativa" (estamos no Perfil), não destaca nenhum item
          selectedItemColor: _bottomNavIndex < 0
              ? const Color(0xFFADB5BD)
              : _verde,
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

class _NavItemPerfil {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final VoidCallback? onTap;

  _NavItemPerfil({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    this.onTap,
  });
}
