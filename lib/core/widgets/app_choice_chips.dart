import 'package:flutter/material.dart';
import 'field_label.dart';

/// Grupo de opções em formato de chip (Wrap de [ChoiceChip]) com o visual
/// padrão do app, usado para categoria de lançamento e forma de pagamento.
class AppChoiceChips<T> extends StatelessWidget {
  const AppChoiceChips({
    super.key,
    required this.items,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    required this.activeColor,
    this.fontSize = 14,
    this.label,
    this.tooltip,
  });

  final List<T> items;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;
  final Color activeColor;
  final double fontSize;
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chips = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final isSelected = item == selected;
        return ChoiceChip(
          label: Text(
            labelOf(item),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
          selected: isSelected,
          // Comportamento de seleção única (tipo radio): tocar no chip já
          // selecionado não pode desmarcá-lo, então ignoramos o valor de
          // toggle que o ChoiceChip envia e sempre reafirmamos o item.
          onSelected: (_) => onSelected(item),
          selectedColor: activeColor,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected
                ? activeColor
                : Colors.black.withValues(alpha: 0.12),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );

    if (label == null) return chips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(text: label!, tooltip: tooltip),
        const SizedBox(height: 10),
        chips,
      ],
    );
  }
}
