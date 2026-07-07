import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'field_label.dart';

/// Seletor numérico com botões de "-" e "+" nas laterais e um campo central
/// editável pelo teclado, usado para quantidade em estoque e em vendas.
class QuantityStepper extends StatefulWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
    required this.onChanged,
    this.width,
    this.padding = const EdgeInsets.all(4),
    this.label,
    this.tooltip,
  });

  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<int> onChanged;
  final double? width;
  final EdgeInsetsGeometry padding;
  final String? label;
  final String? tooltip;

  @override
  State<QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<QuantityStepper> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);

  @override
  void didUpdateWidget(covariant QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (int.tryParse(_controller.text) != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _restoreIfInvalid();
  }

  void _handleChanged(String text) {
    final parsed = int.tryParse(text);
    if (parsed != null) widget.onChanged(parsed);
  }

  void _restoreIfInvalid() {
    if (int.tryParse(_controller.text) == null) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepper = Container(
      width: widget.width ?? double.infinity,
      padding: widget.padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, color: AppTheme.primaryColor),
            onPressed: widget.onDecrement,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _handleChanged,
              onSubmitted: (_) => _restoreIfInvalid(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primaryColor),
            onPressed: widget.onIncrement,
          ),
        ],
      ),
    );

    if (widget.label == null) return stepper;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(text: widget.label!, tooltip: widget.tooltip),
        const SizedBox(height: 8),
        stepper,
      ],
    );
  }
}
