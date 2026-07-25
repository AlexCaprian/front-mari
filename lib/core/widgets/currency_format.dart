import 'package:flutter/services.dart';

/// Formata dígitos digitados livremente como moeda em tempo real: os dois
/// últimos dígitos viram os centavos automaticamente (ex.: "21000" -> "210,00"),
/// sem precisar digitar a vírgula. Usado em todo campo de valor do app.
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final String trimmed = digits.length > 9 ? digits.substring(0, 9) : digits;
    final double value = double.parse(trimmed) / 100;
    final String formatted = formatCurrencyValue(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formata um valor decimal como moeda brasileira, sem o prefixo "R$"
/// (ex.: 1234.5 -> "1.234,50").
String formatCurrencyValue(double value) {
  final String basic = value.toStringAsFixed(2);
  final List<String> parts = basic.split('.');
  String integerPart = parts[0];
  final String decimalPart = parts[1];
  final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  integerPart = integerPart.replaceAllMapped(
    reg,
    (Match match) => '${match[1]}.',
  );
  return '$integerPart,$decimalPart';
}

/// Converte um texto de moeda formatado (ex.: "1.234,56") de volta para
/// double (1234.56). Retorna null se o texto estiver vazio ou inválido.
double? parseCurrencyValue(String text) {
  final normalized = text.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(normalized);
}
