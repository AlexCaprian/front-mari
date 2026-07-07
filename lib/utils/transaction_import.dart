import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../models/models.dart';
import '../widgets/currency_format.dart';
import 'text_normalize.dart';

/// Uma linha válida de despesa/ganho lida de uma planilha (CSV/Excel)
/// importada — vira uma [Transaction] ao ser cadastrada.
class TransactionImportRow {
  const TransactionImportRow({
    required this.rowNumber,
    required this.category,
    required this.amount,
    required this.quantity,
    required this.type,
    required this.occurredAt,
  });

  /// Número da linha na planilha original (1 = cabeçalho), usado nas
  /// mensagens de erro pra o usuário conseguir localizar o problema.
  final int rowNumber;
  final String category;

  /// Valor total do lançamento (coluna "valor" × "qnt").
  final double amount;

  /// Coluna "qnt" (1 quando a planilha não informa) — usada, à parte do
  /// [amount], pra descontar do estoque de um produto de mesmo nome quando
  /// a linha é um ganho (ver [TransactionImportButton]).
  final int quantity;
  final TransactionType type;
  final DateTime occurredAt;
}

/// Resultado de ler e validar a planilha: linhas prontas pra importar e
/// mensagens de erro das linhas que não puderam ser lidas.
class TransactionImportParseResult {
  const TransactionImportParseResult({
    required this.rows,
    required this.parseErrors,
  });

  final List<TransactionImportRow> rows;
  final List<String> parseErrors;
}

const _categoryHeaders = {'nome', 'name', 'categoria', 'category'};
const _valueHeaders = {'valor', 'preco', 'price'};
const _quantityHeaders = {'qnt', 'qtd', 'quantidade', 'quantity'};
const _typeHeaders = {'tipo', 'type'};
const _dateHeaders = {'data', 'date'};

const _incomeTypeValues = {'ganho', 'ganhos', 'income', 'receita', 'entrada'};
const _expenseTypeValues = {
  'despesa',
  'despesas',
  'expense',
  'saida',
  'gasto',
  'gastos',
};

/// Abre o seletor de arquivo do sistema, lê um .csv ou .xlsx escolhido pelo
/// usuário e devolve as linhas já validadas. Retorna `null` se o usuário
/// cancelar a seleção.
Future<TransactionImportParseResult?>
pickAndParseTransactionsSpreadsheet() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv', 'xlsx'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null) {
    return const TransactionImportParseResult(
      rows: [],
      parseErrors: ['Não foi possível ler o arquivo selecionado.'],
    );
  }

  final extension = (file.extension ?? '').toLowerCase();
  final table = extension == 'xlsx'
      ? _readXlsxTable(bytes)
      : _readCsvTable(bytes);
  return _parseTable(table);
}

List<List<String>> _readXlsxTable(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return [];
  final sheet = excel.tables.values.first;
  return sheet.rows
      .map(
        (row) =>
            row.map((cell) => cell?.value?.toString().trim() ?? '').toList(),
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

TransactionImportParseResult _parseTable(List<List<String>> table) {
  if (table.isEmpty) {
    return const TransactionImportParseResult(
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

  final categoryIndex = indexOf(_categoryHeaders);
  final valueIndex = indexOf(_valueHeaders);
  final quantityIndex = indexOf(_quantityHeaders);
  final typeIndex = indexOf(_typeHeaders);
  final dateIndex = indexOf(_dateHeaders);

  if (categoryIndex == null ||
      valueIndex == null ||
      typeIndex == null ||
      dateIndex == null) {
    return const TransactionImportParseResult(
      rows: [],
      parseErrors: [
        'Não encontrei as colunas obrigatórias "nome", "valor", "tipo" e '
            '"data" no cabeçalho da planilha.',
      ],
    );
  }

  String cellAt(List<String> line, int? index) =>
      (index == null || index >= line.length) ? '' : line[index].trim();

  num? parseNumber(String raw) {
    if (raw.isEmpty) return null;
    return num.tryParse(raw) ?? parseCurrencyValue(raw);
  }

  final rows = <TransactionImportRow>[];
  final errors = <String>[];

  for (var i = 1; i < table.length; i++) {
    final line = table[i];
    final rowNumber = i + 1;
    if (line.every((cell) => cell.trim().isEmpty)) continue;

    final category = cellAt(line, categoryIndex);
    if (category.isEmpty) {
      errors.add('Linha $rowNumber: nome/categoria vazio.');
      continue;
    }

    final value = parseNumber(cellAt(line, valueIndex));
    if (value == null || value < 0) {
      errors.add('Linha $rowNumber ("$category"): valor inválido.');
      continue;
    }

    final quantityRaw = cellAt(line, quantityIndex);
    final quantity = quantityRaw.isEmpty ? 1 : parseNumber(quantityRaw);
    if (quantity == null || quantity < 0) {
      errors.add('Linha $rowNumber ("$category"): quantidade inválida.');
      continue;
    }

    final typeRaw = normalizeSpreadsheetText(cellAt(line, typeIndex));
    TransactionType? type;
    if (_incomeTypeValues.contains(typeRaw)) {
      type = TransactionType.income;
    } else if (_expenseTypeValues.contains(typeRaw)) {
      type = TransactionType.expense;
    }
    if (type == null) {
      errors.add(
        'Linha $rowNumber ("$category"): tipo "$typeRaw" não reconhecido '
        '(use "ganho" ou "despesa").',
      );
      continue;
    }

    final occurredAt = _parseDate(cellAt(line, dateIndex));
    if (occurredAt == null) {
      errors.add(
        'Linha $rowNumber ("$category"): data inválida (use dd/mm/aaaa).',
      );
      continue;
    }

    rows.add(
      TransactionImportRow(
        rowNumber: rowNumber,
        category: category,
        amount: value.toDouble() * quantity,
        quantity: quantity.round(),
        type: type,
        occurredAt: occurredAt,
      ),
    );
  }

  return TransactionImportParseResult(rows: rows, parseErrors: errors);
}

final _brDatePattern = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$');
final _isoDatePattern = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');

/// Aceita `dd/mm/aaaa` (formato da planilha de exemplo) e `aaaa-mm-dd` (ISO).
DateTime? _parseDate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final brMatch = _brDatePattern.firstMatch(trimmed);
  if (brMatch != null) {
    final day = int.parse(brMatch.group(1)!);
    final month = int.parse(brMatch.group(2)!);
    final year = int.parse(brMatch.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  final isoMatch = _isoDatePattern.firstMatch(trimmed);
  if (isoMatch != null) {
    final year = int.parse(isoMatch.group(1)!);
    final month = int.parse(isoMatch.group(2)!);
    final day = int.parse(isoMatch.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  return null;
}
