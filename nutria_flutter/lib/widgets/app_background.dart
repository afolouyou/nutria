import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.isDark, this.overlay = true});

  final bool isDark;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          isDark
              ? 'assets/images/fundo.png'
              : 'assets/images/fundo-white.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
        ),
        if (overlay)
          ColoredBox(
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.12),
          ),
      ],
    );
  }
}
