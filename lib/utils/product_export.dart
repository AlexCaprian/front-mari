import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../models/models.dart';

enum ProductExportFormat { csv, xlsx }

/// Gera a planilha com os produtos cadastrados no formato escolhido e abre o
/// diálogo do sistema pra salvar. Retorna `true` se o usuário salvou o
/// arquivo, `false` se cancelou a seleção do local.
Future<bool> exportProducts(
  List<Product> products,
  ProductExportFormat format,
) async {
  final extension = format == ProductExportFormat.csv ? 'csv' : 'xlsx';
  final bytes = format == ProductExportFormat.csv
      ? _buildCsvBytes(products)
      : _buildXlsxBytes(products);

  final path = await FilePicker.saveFile(
    dialogTitle: 'Salvar lista de produtos',
    fileName: 'produtos.$extension',
    type: FileType.custom,
    allowedExtensions: [extension],
    bytes: bytes,
  );
  return path != null;
}

Uint8List _buildCsvBytes(List<Product> products) {
  final rows = <List<dynamic>>[
    ['nome', 'qnt', 'custo', 'valor'],
    for (final product in products)
      [product.name, product.stock, product.cost ?? '', product.price],
  ];
  final csvString = const ListToCsvConverter(eol: '\n').convert(rows);
  return Uint8List.fromList(utf8.encode(csvString));
}

Uint8List _buildXlsxBytes(List<Product> products) {
  final excel = Excel.createExcel();
  const sheetName = 'Produtos';

  excel.appendRow(sheetName, [
    TextCellValue('nome'),
    TextCellValue('qnt'),
    TextCellValue('custo'),
    TextCellValue('valor'),
  ]);
  for (final product in products) {
    excel.appendRow(sheetName, [
      TextCellValue(product.name),
      IntCellValue(product.stock),
      product.cost != null ? DoubleCellValue(product.cost!) : null,
      DoubleCellValue(product.price),
    ]);
  }

  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null && defaultSheet != sheetName) {
    excel.delete(defaultSheet);
  }

  return Uint8List.fromList(excel.encode()!);
}
