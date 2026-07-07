const monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const monthAbbrev = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

/// Últimos [count] meses no formato `YYYY-MM` esperado pela API, do mais
/// antigo pro mais recente (o atual é o último item).
List<String> recentMonths({int count = 12}) {
  final now = DateTime.now();
  return List.generate(count, (i) {
    final date = DateTime(now.year, now.month - (count - 1 - i));
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  });
}

String monthLabel(String yyyyMM) {
  final parts = yyyyMM.split('-');
  final month = int.parse(parts[1]);
  return '${monthNames[month - 1]} de ${parts[0]}';
}

String monthAbbrevLabel(String yyyyMM) =>
    monthAbbrev[int.parse(yyyyMM.split('-')[1]) - 1];

String formatShortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${monthAbbrev[date.month - 1]}';

/// Janelas de 3 meses consecutivos dentro de [months], da mais antiga pra
/// mais recente (usado no seletor de "comparar meses").
List<List<String>> threeMonthWindows(List<String> months) {
  final windows = <List<String>>[];
  for (var i = 0; i + 2 < months.length; i++) {
    windows.add(months.sublist(i, i + 3));
  }
  return windows;
}

String windowLabel(List<String> window) =>
    '${monthAbbrevLabel(window.first)} - ${monthAbbrevLabel(window.last)}';

/// Início (inclusive) e fim (exclusivo) de um mês `YYYY-MM` em UTC — mesma
/// janela usada pelo backend (`back_mari/src/lib/month.ts`) pra filtrar
/// vendas/transações por mês.
({DateTime start, DateTime end}) monthDateRangeUtc(String month) {
  final parts = month.split('-');
  final year = int.parse(parts[0]);
  final monthNum = int.parse(parts[1]);
  return (
    start: DateTime.utc(year, monthNum, 1),
    end: DateTime.utc(year, monthNum + 1, 1),
  );
}
