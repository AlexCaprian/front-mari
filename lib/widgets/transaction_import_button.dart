import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/products_controller.dart';
import '../state/transactions_controller.dart';
import '../utils/transaction_import.dart';

/// Botão "Importar dados" usado na tela de Relatório Mensal: abre o seletor
/// de arquivo, lê uma planilha CSV/Excel com colunas de nome, valor,
/// quantidade (opcional), tipo (ganho/despesa) e data, e cadastra uma
/// transação pra cada linha. Linhas de ganho cujo nome bate (case-insensitive)
/// com um produto já cadastrado também descontam a quantidade vendida do
/// estoque desse produto, mesmo que fique negativo — nunca perde a venda já
/// identificada por falta de estoque cadastrado. Avisa [onImportingChanged]
/// pra tela em volta poder mostrar o overlay de carregamento padrão enquanto
/// os dados são registrados um a um.
class TransactionImportButton extends StatefulWidget {
  const TransactionImportButton({
    super.key,
    this.onImportingChanged,
    this.onImported,
  });

  final ValueChanged<bool>? onImportingChanged;

  /// Chamado depois que pelo menos um lançamento foi registrado, antes do
  /// diálogo de resumo aparecer — pra tela em volta recarregar os dados
  /// (ex.: o resumo do mês pode ter mudado).
  final VoidCallback? onImported;

  @override
  State<TransactionImportButton> createState() =>
      _TransactionImportButtonState();
}

class _TransactionImportButtonState extends State<TransactionImportButton> {
  bool _isImporting = false;

  Future<void> _handleImport() async {
    final parseResult = await pickAndParseTransactionsSpreadsheet();
    if (parseResult == null) return; // usuário cancelou a seleção
    if (!mounted) return;

    if (parseResult.rows.isEmpty) {
      _showSummaryDialog(
        created: 0,
        stockAdjusted: 0,
        errors: parseResult.parseErrors,
      );
      return;
    }

    setState(() => _isImporting = true);
    widget.onImportingChanged?.call(true);

    final transactionsController = context.read<TransactionsController>();
    final productsController = context.read<ProductsController>();

    var created = 0;
    var stockAdjusted = 0;
    final failures = <String>[];

    for (final row in parseResult.rows) {
      final success = await transactionsController.create({
        'type': row.type.apiValue,
        'amount': row.amount,
        'category': row.category,
        'occurredAt': row.occurredAt.toUtc().toIso8601String(),
      });

      if (!success) {
        failures.add(
          'Linha ${row.rowNumber} ("${row.category}"): '
          '${transactionsController.actionError ?? "erro desconhecido"}',
        );
        continue;
      }
      created++;

      if (row.type != TransactionType.income) continue;
      Product? match;
      for (final product in productsController.products) {
        if (product.name.toLowerCase() == row.category.toLowerCase()) {
          match = product;
          break;
        }
      }
      if (match == null) continue;

      final adjusted = await productsController.adjustStockByDelta(
        match.id,
        -row.quantity,
      );
      if (adjusted) stockAdjusted++;
    }

    if (!mounted) return;
    setState(() => _isImporting = false);
    widget.onImportingChanged?.call(false);
    widget.onImported?.call();

    _showSummaryDialog(
      created: created,
      stockAdjusted: stockAdjusted,
      errors: [...parseResult.parseErrors, ...failures],
    );
  }

  void _showSummaryDialog({
    required int created,
    required int stockAdjusted,
    required List<String> errors,
  }) {
    final hasSuccess = created > 0;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          hasSuccess ? 'Importação concluída' : 'Não foi possível importar',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasSuccess) ...[
                Text(
                  '$created lançamento${created == 1 ? '' : 's'} registrado'
                  '${created == 1 ? '' : 's'} com sucesso.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (stockAdjusted > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Estoque de $stockAdjusted produto'
                    '${stockAdjusted == 1 ? '' : 's'} identificado'
                    '${stockAdjusted == 1 ? '' : 's'} pelo nome foi ajustado.',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
              if (errors.isNotEmpty) ...[
                if (hasSuccess) const SizedBox(height: 12),
                Text(
                  '${errors.length} linha${errors.length == 1 ? '' : 's'} '
                  'com problema:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: errors
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '• $e',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _isImporting ? null : _handleImport,
      icon: _isImporting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.upload_file_outlined, size: 18),
      label: const Text('Importar dados'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
