const _accentMap = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c',
};

/// Normaliza texto vindo de planilhas (cabeçalhos, valores de coluna) pra
/// comparação tolerante a acento/caixa: minúsculo, sem espaços nas pontas,
/// sem acentuação.
String normalizeSpreadsheetText(String raw) {
  var normalized = raw.trim().toLowerCase();
  _accentMap.forEach((accented, plain) {
    normalized = normalized.replaceAll(accented, plain);
  });
  return normalized;
}
