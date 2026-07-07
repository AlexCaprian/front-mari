class DashboardActivity {
  const DashboardActivity({
    required this.id,
    required this.kind,
    required this.date,
    required this.description,
    required this.category,
    required this.amount,
    this.quantity,
  });

  /// Id da venda ou do lançamento de origem, usado para editar/excluir.
  final String id;

  /// 'sale' ou 'transaction'.
  final String kind;
  final DateTime date;
  final String description;
  final String category;

  /// Já com sinal: positivo pra venda/ganho, negativo pra despesa.
  final double amount;

  /// Quantidade vendida, só preenchida quando kind == 'sale' (necessária pra
  /// recalcular o unitPrice ao editar o valor total da venda).
  final int? quantity;

  factory DashboardActivity.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    final date = DateTime.parse(json['date'] as String);
    final id = json['id'] as String;

    if (kind == 'sale') {
      final product = json['product'] as Map<String, dynamic>?;
      final quantity = json['quantity'] as int;
      return DashboardActivity(
        id: id,
        kind: kind,
        date: date,
        description: product != null
            ? 'Venda – ${product['name']} ($quantity un.)'
            : 'Venda ($quantity un.)',
        category: 'Venda',
        amount: (json['total'] as num).toDouble(),
        quantity: quantity,
      );
    }

    final type = json['type'] as String;
    final amount = (json['amount'] as num).toDouble();
    final category = json['category'] as String;
    return DashboardActivity(
      id: id,
      kind: kind,
      date: date,
      description: category,
      category: category,
      amount: type == 'expense' ? -amount : amount,
    );
  }

  /// Serialização própria (não é o formato bruto da API) usada pelo cache
  /// local — os campos já vêm computados, então não precisa reprocessar
  /// `product`/`type` como o [fromJson] original faz.
  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'kind': kind,
    'date': date.toIso8601String(),
    'description': description,
    'category': category,
    'amount': amount,
    'quantity': quantity,
  };

  factory DashboardActivity.fromCacheJson(Map<String, dynamic> json) =>
      DashboardActivity(
        id: json['id'] as String,
        kind: json['kind'] as String,
        date: DateTime.parse(json['date'] as String),
        description: json['description'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        quantity: json['quantity'] as int?,
      );
}

class DashboardData {
  const DashboardData({
    required this.month,
    required this.saldoDoMes,
    required this.ganhos,
    required this.despesas,
    required this.activity,
  });

  final String month;
  final double saldoDoMes;
  final double ganhos;
  final double despesas;
  final List<DashboardActivity> activity;

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
    month: json['month'] as String,
    saldoDoMes: (json['saldoDoMes'] as num).toDouble(),
    ganhos: (json['ganhos'] as num).toDouble(),
    despesas: (json['despesas'] as num).toDouble(),
    activity: (json['activity'] as List)
        .map((e) => DashboardActivity.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Serialização/leitura própria pro cache local — ver
  /// [DashboardActivity.toCacheJson].
  Map<String, dynamic> toCacheJson() => {
    'month': month,
    'saldoDoMes': saldoDoMes,
    'ganhos': ganhos,
    'despesas': despesas,
    'activity': activity.map((a) => a.toCacheJson()).toList(),
  };

  factory DashboardData.fromCacheJson(Map<String, dynamic> json) =>
      DashboardData(
        month: json['month'] as String,
        saldoDoMes: (json['saldoDoMes'] as num).toDouble(),
        ganhos: (json['ganhos'] as num).toDouble(),
        despesas: (json['despesas'] as num).toDouble(),
        activity: (json['activity'] as List)
            .map(
              (e) =>
                  DashboardActivity.fromCacheJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
}
