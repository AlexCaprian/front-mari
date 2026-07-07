import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'field_label.dart';

/// Dropdown com caixa arredondada padrão do app, usado para seletores de
/// mês, intervalo de meses e produto.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.isExpanded = false,
    this.label,
    this.tooltip,
  });

  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;
  final bool isExpanded;
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final dropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: isExpanded,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.primaryColor,
          ),
          onChanged: onChanged,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    labelOf(item),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (label == null) return dropdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(text: label!, tooltip: tooltip),
        const SizedBox(height: 8),
        dropdown,
      ],
    );
  }
}
