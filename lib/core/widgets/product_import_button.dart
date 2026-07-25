import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/products_controller.dart';
import '../utils/product_import.dart';

/// Botão "Importar" usado na tela de Produtos (mobile e desktop): abre o
/// seletor de arquivo, lê uma planilha CSV/Excel com colunas de nome,
/// quantidade, custo (opcional) e valor, e cadastra/atualiza os produtos.
class ProductImportButton extends StatefulWidget {
  const ProductImportButton({super.key});

  @override
  State<ProductImportButton> createState() => _ProductImportButtonState();
}

class _ProductImportButtonState extends State<ProductImportButton> {
  bool _isImporting = false;

  Future<void> _handleImport() async {
    final parseResult = await pickAndParseProductsSpreadsheet();
    if (parseResult == null) return; // usuário cancelou a seleção
    if (!mounted) return;

    if (parseResult.rows.isEmpty) {
      _showSummaryDialog(created: 0, updated: 0, errors: parseResult.parseErrors);
      return;
    }

    setState(() => _isImporting = true);
    final controller = context.read<ProductsController>();
    final summary = await controller.importFromRows(parseResult.rows);
    if (!mounted) return;
    setState(() => _isImporting = false);

    _showSummaryDialog(
      created: summary.created,
      updated: summary.updated,
      errors: [...parseResult.parseErrors, ...summary.failures],
    );
  }

  void _showSummaryDialog({
    required int created,
    required int updated,
    required List<String> errors,
  }) {
    final hasSuccess = created > 0 || updated > 0;
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
              if (hasSuccess)
                Text(
                  '$created produto${created == 1 ? '' : 's'} cadastrado'
                  '${created == 1 ? '' : 's'} e $updated atualizado'
                  '${updated == 1 ? '' : 's'}.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
      label: const Text('Importar'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
