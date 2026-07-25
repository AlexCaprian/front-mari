import 'package:flutter/material.dart';

/// Widget padrão para alternar entre loading, erro (mensagem da API via
/// [ApiException]), vazio e conteúdo carregado — usado em toda tela que
/// consome um controller (`isLoading`/`errorMessage`/lista vazia).
class AsyncStateView extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.isLoading,
    this.errorMessage,
    required this.isEmpty,
    required this.emptyMessage,
    required this.builder,
    this.padding = EdgeInsets.zero,
  });

  final bool isLoading;
  final String? errorMessage;
  final bool isEmpty;
  final String emptyMessage;
  final WidgetBuilder builder;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: padding,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMessage != null) {
      return Padding(
        padding: padding,
        child: Text(
          errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (isEmpty) {
      return Padding(
        padding: padding,
        child: Text(
          emptyMessage,
          style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
        ),
      );
    }
    return builder(context);
  }
}
