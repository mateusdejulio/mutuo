import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mutuo/services/api_service.dart';

const _verde = Color(0xFF3A5A40);
const _verdeMedio = Color(0xFF588157);

const List<String> _focosServicoOng = [
  'culinária',
  'jardinagem',
  'música',
  'tecnologia',
  'educação',
  'animais',
  'idosos',
  'ambiental',
  'outro',
];

/// Abre o modal de cadastro/edição de atividade da ONG.
/// Reutilizável em qualquer tela: passe [atividade] pra abrir em modo de
/// edição, ou deixe null pra cadastrar uma nova. [onSucesso] é chamado
/// depois que a atividade é salva com sucesso, pra a tela que chamou
/// recarregar a lista dela.
///
/// [totalAtividades] e [ongPremium] são usados para verificar o limite
/// do plano gratuito (3 atividades) DENTRO do próprio modal, então a
/// checagem não depende só do botão que abriu o modal.
Future<void> abrirModalAtividadeOng({
  required BuildContext context,
  required String cnpj,
  required VoidCallback onSucesso,
  Map<String, dynamic>? atividade,
  int totalAtividades = 0,
  bool ongPremium = false,
}) async {
  final api = ApiService();
  final picker = ImagePicker();

  final editando = atividade != null;

  // Limite só se aplica a cadastro de atividade NOVA. Editar uma
  // atividade que já existe não conta como "atividade a mais".
  final limiteAtingido = !editando && !ongPremium && totalAtividades >= 3;

  final nomeCtrl = TextEditingController(
    text: atividade?['nomeServico']?.toString() ?? '',
  );
  final descCtrl = TextEditingController(
    text: atividade?['descricao']?.toString() ?? '',
  );
  final duracaoCtrl = TextEditingController(
    text: atividade?['horas']?.toString() ?? '',
  );

  // Normaliza o foco vindo do banco (evita mismatch de maiúscula/acento
  // com a lista fixa) e garante que o valor atual sempre exista na lista.
  String? focoSelecionado = atividade?['foco']?.toString();
  if (focoSelecionado != null) {
    focoSelecionado = _focosServicoOng.firstWhere(
      (f) => f.toLowerCase() == focoSelecionado!.toLowerCase(),
      orElse: () => focoSelecionado!,
    );
  }
  final focosDisponiveis = List<String>.from(_focosServicoOng);
  if (focoSelecionado != null && !focosDisponiveis.contains(focoSelecionado)) {
    focosDisponiveis.add(focoSelecionado);
  }

  XFile? imagemSelecionada;
  bool enviando = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) {
      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> escolherImagem() async {
            final imagem = await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 1024,
              imageQuality: 85,
            );
            if (imagem != null) setModalState(() => imagemSelecionada = imagem);
          }

          Future<void> confirmar() async {
            if (limiteAtingido) return;

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
                ? await api.atualizarServicoOng(
                    id: atividade!['id'].toString(),
                    nomeServico: nomeCtrl.text.trim(),
                    descricao: descCtrl.text.trim(),
                    foco: focoSelecionado!,
                    duracao: duracaoCtrl.text.trim(),
                    imagemBytes: bytes,
                    imagemNome: nomeArquivo,
                  )
                : await api.cadastrarServicoOng(
                    cnpj: cnpj,
                    nomeServico: nomeCtrl.text.trim(),
                    descricao: descCtrl.text.trim(),
                    foco: focoSelecionado!,
                    duracao: duracaoCtrl.text.trim(),
                    imagemBytes: bytes,
                    imagemNome: nomeArquivo,
                  );

            setModalState(() => enviando = false);

            if (resultado['sucesso'] == true) {
              if (!context.mounted) return;
              Navigator.pop(modalContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    editando
                        ? 'Atividade atualizada com sucesso!'
                        : 'Atividade cadastrada com sucesso!',
                  ),
                ),
              );
              onSucesso();
            } else {
              ScaffoldMessenger.of(modalContext).showSnackBar(
                SnackBar(
                  content: Text(
                    resultado['erro']?.toString() ??
                        (editando
                            ? 'Não foi possível atualizar a atividade.'
                            : 'Não foi possível cadastrar a atividade.'),
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
                                ? 'Editar atividade'
                                : 'Cadastro de atividade',
                            style: GoogleFonts.quicksand(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (limiteAtingido) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white38),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Limite de atividades atingido',
                                    style: GoogleFonts.quicksand(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Seu plano gratuito permite até 3 atividades ativas. Faça upgrade para o plano Premium para cadastrar mais atividades.',
                              style: GoogleFonts.quicksand(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.85),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(modalContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _verde,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.workspace_premium_outlined),
                          label: Text(
                            'Entendi',
                            style: GoogleFonts.quicksand(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      const SizedBox(height: 22),

                      _modalLabel('Nome da atividade', Icons.badge_outlined),
                      _modalInput(
                        controller: nomeCtrl,
                        hint: 'Ex: Aula de reforço escolar',
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
                                'Descreva a atividade, público-alvo e objetivos...',
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

                      _modalLabel('Imagem da atividade', Icons.image_outlined),
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
                                          errorBuilder: (_, __, ___) =>
                                              _imagemIndisponivel(),
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
                              (atividade!['imagem']?.toString().isNotEmpty ??
                                  false)) ...[
                            const SizedBox(width: 12),
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    '${ApiService.baseUrl}${atividade['imagem']}',
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _imagemIndisponivel(),
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
                                      : 'Cadastrar atividade'),
                            style: GoogleFonts.quicksand(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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

Widget _imagemIndisponivel() {
  return Container(
    width: 76,
    height: 76,
    color: const Color(0xFFE5E2D8),
    alignment: Alignment.center,
    child: const Icon(
      Icons.broken_image_outlined,
      color: Color(0xFF9E9E9E),
      size: 28,
    ),
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
