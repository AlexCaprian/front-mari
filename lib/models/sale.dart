import 'product.dart';

enum PaymentMethod { dinheiro, pix, cartao, fiado }

extension PaymentMethodApi on PaymentMethod {
  String get apiValue => name;
}

PaymentMethod paymentMethodFromApi(String value) =>
    PaymentMethod.values.firstWhere((e) => e.name == value);

class Sale {
  const Sale({
    required this.id,
    required this.productId,
    this.product,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final Product? product;
  final int quantity;
  final double unitPrice;
  final double total;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id'] as String,
    productId: json['productId'] as String,
    product: json['product'] == null
        ? null
        : Product.fromJson(json['product'] as Map<String, dynamic>),
    quantity: json['quantity'] as int,
    unitPrice: (json['unitPrice'] as num).toDouble(),
    total: (json['total'] as num).toDouble(),
    paymentMethod: paymentMethodFromApi(json['paymentMethod'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  /// Corpo pra POST /sales.
  Map<String, dynamic> toCreateBody() => {
    'productId': productId,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'paymentMethod': paymentMethod.apiValue,
  };

  /// Serialização completa (com id/timestamps) usada pelo cache local —
  /// espelha [fromJson], que também serve pra decodificar de volta.
  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'product': product?.toJson(),
    'quantity': quantity,
    'unitPrice': unitPrice,
    'total': total,
    'paymentMethod': paymentMethod.apiValue,
    'createdAt': createdAt.toIso8601String(),
  };
}
