import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/products_controller.dart';
import '../utils/product_export.dart';

/// Botão "Exportar" usado na tela de Produtos (mobile e desktop): deixa o
/// usuário escolher entre CSV ou Excel e salva a lista de produtos
/// cadastrados nesse formato.
class ProductExportButton extends StatefulWidget {
  const ProductExportButton({super.key});

  @override
  State<ProductExportButton> createState() => _ProductExportButtonState();
}

class _ProductExportButtonState extends State<ProductExportButton> {
  bool _isExporting = false;

  Future<void> _handleExport(ProductExportFormat format) async {
    final products = context.read<ProductsController>().products;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há produtos cadastrados para exportar.'),
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    bool saved;
    String? errorMessage;
    try {
      saved = await exportProducts(products, format);
    } catch (e) {
      saved = false;
      errorMessage = 'Não foi possível exportar a lista: $e';
    }
    if (!mounted) return;
    setState(() => _isExporting = false);

    if (errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lista de produtos exportada com sucesso!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: () => _handleExport(ProductExportFormat.csv),
          child: const Text('Exportar como CSV'),
        ),
        MenuItemButton(
          onPressed: () => _handleExport(ProductExportFormat.xlsx),
          child: const Text('Exportar como Excel (.xlsx)'),
        ),
      ],
      builder: (context, controller, child) {
        return OutlinedButton.icon(
          onPressed: _isExporting
              ? null
              : () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
          icon: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined, size: 18),
          label: const Text('Exportar'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}
