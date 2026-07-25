import 'package:flutter/material.dart';

/// Rótulo em negrito com um ícone de informação opcional ao lado (toque
/// para exibir a explicação), usado acima de todo campo de entrada do app.
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.text, this.tooltip});

  final String text;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (tooltip != null) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: tooltip!,
            triggerMode: TooltipTriggerMode.tap,
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
        ],
      ],
    );
  }
}
