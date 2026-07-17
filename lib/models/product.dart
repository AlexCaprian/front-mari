class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.cost,
    required this.stock,
    this.stockRequired = true,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final double price;
  final double? cost;
  final int stock;
  // Se false, o produto não tem controle de quantidade em estoque (ex:
  // serviços) e o campo de estoque nem aparece no cadastro/edição.
  final bool stockRequired;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
    cost: (json['cost'] as num?)?.toDouble(),
    stock: json['stock'] as int,
    stockRequired: json['stockRequired'] as bool? ?? true,
    photoUrl: json['photoUrl'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  /// Corpo pra POST /products e PUT /products/:id — só os campos editáveis.
  Map<String, dynamic> toRequestBody() => {
    'name': name,
    'price': price,
    'cost': cost,
    'stock': stock,
    'stockRequired': stockRequired,
    'photoUrl': photoUrl,
  };

  /// Serialização completa (com id/timestamps) usada pelo cache local —
  /// espelha [fromJson], que também serve pra decodificar de volta.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'cost': cost,
    'stock': stock,
    'stockRequired': stockRequired,
    'photoUrl': photoUrl,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
