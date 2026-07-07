import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../widgets/currency_format.dart';
import 'text_normalize.dart';

/// Uma linha válida de produto lida de uma planilha (CSV/Excel) importada.
class ProductImportRow {
  const ProductImportRow({
    required this.rowNumber,
    required this.name,
    required this.quantity,
    required this.price,
    this.cost,
  });

  /// Número da linha na planilha original (1 = cabeçalho), usado nas
  /// mensagens de erro pra o usuário conseguir localizar o problema.
  final int rowNumber;
  final String name;
  final int quantity;
  final double price;
  final double? cost;
}

/// Resultado de ler e validar a planilha: linhas prontas pra importar e
/// mensagens de erro das linhas que não puderam ser lidas.
class ProductImportParseResult {
  const ProductImportParseResult({required this.rows, required this.parseErrors});

  final List<ProductImportRow> rows;
  final List<String> parseErrors;
}

/// Resultado de efetivamente criar/atualizar os produtos das linhas
/// importadas.
class ProductImportSummary {
  const ProductImportSummary({
    required this.created,
    required this.updated,
    required this.failures,
  });

  final int created;
  final int updated;
  final List<String> failures;
}

const _nameHeaders = {'nome', 'name', 'produto'};
const _quantityHeaders = {
  'qnt',
  'qtd',
  'quantidade',
  'estoque',
  'stock',
  'quantity',
};
const _costHeaders = {'custo', 'cost'};
const _priceHeaders = {'valor', 'preco', 'price'};

/// Abre o seletor de arquivo do sistema, lê um .csv ou .xlsx escolhido pelo
/// usuário e devolve as linhas já validadas. Retorna `null` se o usuário
/// cancelar a seleção.
Future<ProductImportParseResult?> pickAndParseProductsSpreadsheet() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv', 'xlsx'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null) {
    return const ProductImportParseResult(
      rows: [],
      parseErrors: ['Não foi possível ler o arquivo selecionado.'],
    );
  }

  final extension = (file.extension ?? '').toLowerCase();
  final table = extension == 'xlsx' ? _readXlsxTable(bytes) : _readCsvTable(bytes);
  return _parseTable(table);
}

List<List<String>> _readXlsxTable(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return [];
  final sheet = excel.tables.values.first;
  return sheet.rows
      .map(
        (row) => row.map((cell) => cell?.value?.toString().trim() ?? '').toList(),
      )
      .toList();
}

List<List<String>> _readCsvTable(Uint8List bytes) {
  final content = utf8
      .decode(bytes, allowMalformed: true)
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  if (content.trim().isEmpty) return [];

  final firstLine = content.split('\n').firstWhere(
    (line) => line.trim().isNotEmpty,
    orElse: () => '',
  );
  final commaCount = ','.allMatches(firstLine).length;
  final semicolonCount = ';'.allMatches(firstLine).length;
  final delimiter = semicolonCount > commaCount ? ';' : ',';

  final rows = CsvToListConverter(
    fieldDelimiter: delimiter,
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(content);

  return rows
      .map((row) => row.map((cell) => cell.toString().trim()).toList())
      .toList();
}

ProductImportParseResult _parseTable(List<List<String>> table) {
  if (table.isEmpty) {
    return const ProductImportParseResult(
      rows: [],
      parseErrors: ['A planilha está vazia.'],
    );
  }

  final header = table.first.map(normalizeSpreadsheetText).toList();
  int? indexOf(Set<String> aliases) {
    for (var i = 0; i < header.length; i++) {
      if (aliases.contains(header[i])) return i;
    }
    return null;
  }

  final nameIndex = indexOf(_nameHeaders);
  final priceIndex = indexOf(_priceHeaders);
  final quantityIndex = indexOf(_quantityHeaders);
  final costIndex = indexOf(_costHeaders);

  if (nameIndex == null || priceIndex == null) {
    return const ProductImportParseResult(
      rows: [],
      parseErrors: [
        'Não encontrei as colunas obrigatórias "nome" e "valor" no '
            'cabeçalho da planilha.',
      ],
    );
  }

  String cellAt(List<String> line, int? index) =>
      (index == null || index >= line.length) ? '' : line[index].trim();

  num? parseNumber(String raw) {
    if (raw.isEmpty) return null;
    return num.tryParse(raw) ?? parseCurrencyValue(raw);
  }

  final rows = <ProductImportRow>[];
  final errors = <String>[];

  for (var i = 1; i < table.length; i++) {
    final line = table[i];
    final rowNumber = i + 1;
    if (line.every((cell) => cell.trim().isEmpty)) continue;

    final name = cellAt(line, nameIndex);
    if (name.isEmpty) {
      errors.add('Linha $rowNumber: nome do produto vazio.');
      continue;
    }

    final price = parseNumber(cellAt(line, priceIndex));
    if (price == null || price < 0) {
      errors.add('Linha $rowNumber ("$name"): valor inválido.');
      continue;
    }

    final quantityRaw = cellAt(line, quantityIndex);
    final quantity = quantityRaw.isEmpty ? 0 : parseNumber(quantityRaw);
    if (quantity == null || quantity < 0) {
      errors.add('Linha $rowNumber ("$name"): quantidade inválida.');
      continue;
    }

    final costRaw = cellAt(line, costIndex);
    double? cost;
    if (costRaw.isNotEmpty) {
      final costValue = parseNumber(costRaw);
      if (costValue == null || costValue < 0) {
        errors.add('Linha $rowNumber ("$name"): custo inválido.');
        continue;
      }
      cost = costValue.toDouble();
    }

    rows.add(
      ProductImportRow(
        rowNumber: rowNumber,
        name: name,
        quantity: quantity.round(),
        price: price.toDouble(),
        cost: cost,
      ),
    );
  }

  return ProductImportParseResult(rows: rows, parseErrors: errors);
}
