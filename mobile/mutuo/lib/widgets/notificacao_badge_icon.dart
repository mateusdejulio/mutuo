import 'package:flutter/material.dart';
import 'package:mutuo/services/solicitacao_sessao_service.dart';

/// Ícone do sino de notificações com o contador de solicitações não lidas
/// sobreposto. Ouve [SolicitacaoSessaoService.totalNaoLidas], mantido
/// globalmente enquanto a sessão está ativa — mesmo padrão do [ChatBadgeIcon].
class NotificacaoBadgeIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;

  const NotificacaoBadgeIcon({
    super.key,
    this.icon = Icons.notifications_outlined,
    this.size = 22,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SolicitacaoSessaoService.instance.totalNaoLidas,
      builder: (context, total, _) {
        final icone = Icon(icon, color: color, size: size);
        if (total <= 0) return icone;

        return Badge(
          label: Text(total > 99 ? '99+' : '$total'),
          backgroundColor: const Color(0xFFC1121F),
          child: icone,
        );
      },
    );
  }
}
