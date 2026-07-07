enum TransactionType { expense, income }

extension TransactionTypeApi on TransactionType {
  String get apiValue => name;
}

TransactionType transactionTypeFromApi(String value) =>
    TransactionType.values.firstWhere((e) => e.name == value);

class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.occurredAt,
    required this.createdAt,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final String category;
  final DateTime occurredAt;
  final DateTime createdAt;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    type: transactionTypeFromApi(json['type'] as String),
    amount: (json['amount'] as num).toDouble(),
    category: json['category'] as String,
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  /// Corpo pra POST /transactions e PUT /transactions/:id.
  Map<String, dynamic> toRequestBody() => {
    'type': type.apiValue,
    'amount': amount,
    'category': category,
    'occurredAt': occurredAt.toIso8601String(),
  };

  /// Serialização completa (com id/timestamps) usada pelo cache local —
  /// espelha [fromJson], que também serve pra decodificar de volta.
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.apiValue,
    'amount': amount,
    'category': category,
    'occurredAt': occurredAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}
