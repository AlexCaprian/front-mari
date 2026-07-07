import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant { primary, outlined }

/// Botão padrão da aplicação: só é preciso passar o texto e, opcionalmente,
/// ícone e cor — o estado de carregamento (spinner substituindo o
/// conteúdo) e o visual preenchido/contornado ficam centralizados aqui.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.color,
    this.fullWidth = false,
    this.padding,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final Color? color;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.primaryColor;
    final spinnerColor = variant == AppButtonVariant.primary
        ? Colors.white
        : effectiveColor;

    Widget child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor,
            ),
          )
        : icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    if (padding != null) {
      child = Padding(padding: padding!, child: child);
    }

    final onTap = isLoading ? null : onPressed;

    final button = variant == AppButtonVariant.primary
        ? ElevatedButton(
            onPressed: onTap,
            style: color != null
                ? ElevatedButton.styleFrom(backgroundColor: color)
                : null,
            child: child,
          )
        : OutlinedButton(
            onPressed: onTap,
            style: color != null
                ? OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color!, width: 2),
                  )
                : null,
            child: child,
          );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
