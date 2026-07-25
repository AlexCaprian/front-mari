class MonthlyReportCategory {
  const MonthlyReportCategory({
    required this.category,
    required this.value,
    required this.percentage,
  });

  final String category;
  final double value;
  final double percentage;

  factory MonthlyReportCategory.fromJson(Map<String, dynamic> json) =>
      MonthlyReportCategory(
        category: json['category'] as String,
        value: (json['value'] as num).toDouble(),
        percentage: (json['percentage'] as num).toDouble(),
      );

  Map<String, dynamic> toCacheJson() => {
    'category': category,
    'value': value,
    'percentage': percentage,
  };
}

class MonthlyReport {
  const MonthlyReport({
    required this.month,
    required this.ganhos,
    required this.despesas,
    required this.saldo,
    required this.custoProdutos,
    required this.lucro,
    required this.categories,
  });

  final String month;
  final double ganhos;
  final double despesas;
  final double saldo;
  final double custoProdutos;
  final double lucro;
  final List<MonthlyReportCategory> categories;

  factory MonthlyReport.fromJson(Map<String, dynamic> json) => MonthlyReport(
    month: json['month'] as String,
    ganhos: (json['ganhos'] as num).toDouble(),
    despesas: (json['despesas'] as num).toDouble(),
    saldo: (json['saldo'] as num).toDouble(),
    custoProdutos: (json['custoProdutos'] as num).toDouble(),
    lucro: (json['lucro'] as num).toDouble(),
    categories: (json['categories'] as List)
        .map((e) => MonthlyReportCategory.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toCacheJson() => {
    'month': month,
    'ganhos': ganhos,
    'despesas': despesas,
    'saldo': saldo,
    'custoProdutos': custoProdutos,
    'lucro': lucro,
    'categories': categories.map((c) => c.toCacheJson()).toList(),
  };

  factory MonthlyReport.fromCacheJson(Map<String, dynamic> json) =>
      MonthlyReport(
        month: json['month'] as String,
        ganhos: (json['ganhos'] as num).toDouble(),
        despesas: (json['despesas'] as num).toDouble(),
        saldo: (json['saldo'] as num).toDouble(),
        custoProdutos: (json['custoProdutos'] as num).toDouble(),
        lucro: (json['lucro'] as num).toDouble(),
        categories: (json['categories'] as List)
            .map(
              (e) => MonthlyReportCategory.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
}

class MonthComparison {
  const MonthComparison({required this.month, required this.balance});

  final String month;
  final double balance;

  factory MonthComparison.fromJson(Map<String, dynamic> json) =>
      MonthComparison(
        month: json['month'] as String,
        balance: (json['balance'] as num).toDouble(),
      );

  Map<String, dynamic> toCacheJson() => {'month': month, 'balance': balance};
}
