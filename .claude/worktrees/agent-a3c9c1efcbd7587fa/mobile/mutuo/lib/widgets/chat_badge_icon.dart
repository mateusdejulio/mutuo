import 'package:flutter/material.dart';
import 'package:mutuo/services/chat_sessao_service.dart';

/// Ícone de item da navBar com o contador de mensagens não lidas do chat
/// sobreposto (usado na aba "Chat"). Ouve [ChatSessaoService.totalNaoLidas],
/// mantido globalmente enquanto a sessão está ativa.
class ChatBadgeIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const ChatBadgeIcon({super.key, required this.icon, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ChatSessaoService.instance.totalNaoLidas,
      builder: (context, total, _) {
        final icone = Icon(icon, size: size);
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
