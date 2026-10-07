import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _verde = Color(0xFF3A5A40);
const _verdeMedio = Color(0xFF588157);
const _bege = Color(0xFFE5E2D8);

/// Executa [tarefa] (o envio do serviço pra API) mostrando por cima de tudo
/// uma tela de "verificando com IA". Usa showDialog, que fica acima do
/// bottom sheet do formulário; um SnackBar ficaria escondido atrás dele.
Future<T> comProcessamentoModeracao<T>(
  BuildContext context,
  Future<T> Function() tarefa,
) async {
  BuildContext? dialogContext;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (ctx) {
      dialogContext = ctx;
      return const PopScope(canPop: false, child: _ProcessamentoModeracao());
    },
  );

  try {
    return await tarefa();
  } finally {
    // Espera o diálogo montar caso a resposta chegue antes do primeiro frame
    if (dialogContext == null) await WidgetsBinding.instance.endOfFrame;
    if (dialogContext != null && dialogContext!.mounted) {
      Navigator.of(dialogContext!).pop();
    }
  }
}

class _ProcessamentoModeracao extends StatefulWidget {
  const _ProcessamentoModeracao();

  @override
  State<_ProcessamentoModeracao> createState() =>
      _ProcessamentoModeracaoState();
}

class _ProcessamentoModeracaoState extends State<_ProcessamentoModeracao> {
  static const _etapas = [
    'Lendo as informações do serviço...',
    'Verificando as diretrizes do Mútuo...',
    'Quase pronto...',
  ];
  int _etapa = 0;

  @override
  void initState() {
    super.initState();
    _avancar();
  }

  Future<void> _avancar() async {
    while (mounted && _etapa < _etapas.length - 1) {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => _etapa++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _verde,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: const [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: _bege,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  Icon(Icons.auto_awesome_rounded, color: _bege, size: 30),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Verificando seu serviço',
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nossa IA está analisando o conteúdo para garantir que ele segue as diretrizes do Mútuo. Isso pode levar alguns segundos.',
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                fontSize: 13,
                color: Colors.white.withOpacity(0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _etapas[_etapa],
                key: ValueKey(_etapa),
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _bege,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Popup de serviço bloqueado pela moderação. É um diálogo (e não SnackBar)
/// pra aparecer por cima do bottom sheet do formulário.
Future<void> mostrarBloqueioModeracao(
  BuildContext context, {
  String? mensagem,
}) {
  const apoio =
      'Não foi possível publicar este serviço. O conteúdo informado pode violar as diretrizes do Mútuo. Revise as informações e tente novamente.';
  final temMensagem = mensagem != null && mensagem.trim().isNotEmpty;

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: _bege,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withOpacity(0.15),
              ),
              child: const Icon(
                Icons.block_rounded,
                color: Colors.redAccent,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Serviço não publicado',
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _verde,
              ),
            ),
            if (temMensagem) ...[
              const SizedBox(height: 10),
              Text(
                mensagem.trim(),
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF344E41),
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              apoio,
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                fontSize: 12,
                color: const Color(0xFF6B705C),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verdeMedio,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Revisar serviço',
                  style: GoogleFonts.quicksand(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
