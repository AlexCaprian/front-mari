import 'package:flutter/material.dart';

/// Largura (em pixels lógicos) a partir da qual o layout desktop
/// (sidebar persistente) substitui o layout mobile.
const double kDesktopBreakpoint = 900.0;

/// Alterna entre um layout mobile e um layout desktop de acordo com a
/// largura disponível, reagindo em tempo real ao redimensionar a janela
/// (Web/Windows/macOS/Linux) sem precisar trocar de rota.
class ResponsiveLayout extends StatelessWidget {
  final WidgetBuilder mobileBuilder;
  final WidgetBuilder desktopBuilder;

  const ResponsiveLayout({
    super.key,
    required this.mobileBuilder,
    required this.desktopBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kDesktopBreakpoint) {
          return desktopBuilder(context);
        }
        return mobileBuilder(context);
      },
    );
  }
}
