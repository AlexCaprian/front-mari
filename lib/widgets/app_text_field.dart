import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'currency_format.dart';
import 'field_label.dart';

/// Campo de texto padrão da aplicação: rótulo em negrito (com ícone de
/// informação opcional ao lado) acima de um [TextFormField] com as bordas
/// arredondadas usadas em todo o app (cinza no estado normal, roxa em foco,
/// vermelha em erro).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.tooltip,
    this.controller,
    this.hintText,
    this.prefixText,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.onChanged,
    this.style,
    this.focusColor,
    this.filled = false,
    this.fillColor,
  });

  final String? label;
  final String? tooltip;
  final TextEditingController? controller;
  final String? hintText;
  final String? prefixText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final bool enableSuggestions;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;
  final Color? focusColor;
  final bool filled;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final color = focusColor ?? AppTheme.primaryColor;

    final field = TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      onChanged: onChanged,
      style: style,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: (style ?? const TextStyle()).copyWith(
          color: Colors.black.withValues(alpha: 0.3),
        ),
        prefixText: prefixText,
        prefixStyle: style,
        filled: filled,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 2.0,
          ),
        ),
      ),
    );

    if (label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(text: label!, tooltip: tooltip),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

/// Campo de valor em reais: já vem com teclado decimal, prefixo "R$" e
/// placeholder "0,00" — só falta o rótulo e o controller.
class MoneyTextField extends StatelessWidget {
  const MoneyTextField({
    super.key,
    required this.controller,
    this.label,
    this.tooltip,
    this.validator,
    this.onChanged,
    this.style,
    this.focusColor,
  });

  final TextEditingController controller;
  final String? label;
  final String? tooltip;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;
  final Color? focusColor;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      tooltip: tooltip,
      controller: controller,
      hintText: '0,00',
      prefixText: 'R\$ ',
      keyboardType: TextInputType.number,
      inputFormatters: [CurrencyInputFormatter()],
      validator: validator,
      onChanged: onChanged,
      style: style,
      focusColor: focusColor,
    );
  }
}
