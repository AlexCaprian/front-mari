import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_routes.dart';
import '../services/dio_client.dart';
import '../services/local_cache.dart';
import '../services/local_ids.dart';
import '../services/pending_operation.dart';
import '../services/session_events.dart';
import '../services/sync_queue.dart';
import '../services/sync_service.dart';
import '../utils/product_import.dart';

class ProductsController extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  // Erro ao carregar a lista (usado pelo AsyncStateView da tela de produtos).
  String? _errorMessage;
  // true quando a lista exibida veio do cache local (API inacessível).
  bool _isOffline = false;
  // Erro de criar/editar/excluir um produto — fica separado do erro de
  // carregamento acima para uma falha ao excluir não fazer a lista inteira
  // sumir e virar uma tela de erro.
  String? _actionError;
  int? _actionErrorStatusCode;

  ProductsController() {
    SyncService.instance.addListener(_onSynced);
    SessionEvents.instance.addListener(_onSessionEnded);
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSynced);
    SessionEvents.instance.removeListener(_onSessionEnded);
    super.dispose();
  }

  // Quando a sincronização em segundo plano confirma alguma pendência (ex.:
  // um produto criado offline ganhou id real), recarrega da API pra
  // substituir os ids locais pelos reais na tela.
  void _onSynced() {
    if (!_isLoading) load();
  }

  // Sessão encerrada (logout ou token expirado): esse controller é único
  // durante a vida do app, então sem isso continuaria mostrando os produtos
  // da conta anterior até a próxima tela chamar `load()`.
  void _onSessionEnded() {
    _products = [];
    _isLoading = false;
    _errorMessage = null;
    _isOffline = false;
    _actionError = null;
    _actionErrorStatusCode = null;
    notifyListeners();
  }

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;
  String? get actionError => _actionError;
  int? get actionErrorStatusCode => _actionErrorStatusCode;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _products = await ApiRoutes.getProducts();
      _isOffline = false;
      unawaited(SyncService.instance.trySync());
      await LocalCache.instance.saveList(
        CacheKeys.products,
        _products.map((p) => p.toJson()).toList(),
      );
    } on ApiException catch (e) {
      final cached = await LocalCache.instance.readList(CacheKeys.products);
      if (cached != null) {
        _products = cached.map(Product.fromJson).toList();
        _isOffline = true;
      } else {
        _errorMessage = e.message;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create(Map<String, dynamic> body) => _mutate(
    online: () async {
      final product = await ApiRoutes.createProduct(body);
      _products = [product, ..._products];
      await LocalCache.instance.upsertInList(
        CacheKeys.products,
        product.toJson(),
        'id',
      );
    },
    offline: () async {
      final localId = LocalIds.generate();
      final now = DateTime.now();
      final product = Product(
        id: localId,
        name: body['name'] as String,
        price: (body['price'] as num).toDouble(),
        cost: (body['cost'] as num?)?.toDouble(),
        stock: body['stock'] as int? ?? 0,
        photoUrl: body['photoUrl'] as String?,
        createdAt: now,
        updatedAt: now,
      );
      _products = [product, ..._products];
      await LocalCache.instance.upsertInList(
        CacheKeys.products,
        product.toJson(),
        'id',
      );
      await SyncQueue.instance.enqueueCreate(
        PendingEntity.product,
        localId,
        body,
      );
    },
  );

  Future<bool> update(String id, Map<String, dynamic> body) => _mutate(
    online: () async {
      final updated = await ApiRoutes.updateProduct(id, body);
      _products = [
        for (final p in _products)
          if (p.id == id) updated else p,
      ];
      await LocalCache.instance.upsertInList(
        CacheKeys.products,
        updated.toJson(),
        'id',
      );
    },
    offline: () async {
      Product? existing;
      for (final p in _products) {
        if (p.id == id) {
          existing = p;
          break;
        }
      }
      if (existing != null) {
        final updated = Product.fromJson({...existing.toJson(), ...body});
        _products = [
          for (final p in _products)
            if (p.id == id) updated else p,
        ];
        await LocalCache.instance.upsertInList(
          CacheKeys.products,
          updated.toJson(),
          'id',
        );
      }
      await SyncQueue.instance.enqueueUpdate(PendingEntity.product, id, body);
    },
  );

  Future<bool> delete(String id) => _mutate(
    online: () async {
      await ApiRoutes.deleteProduct(id);
      _products = _products.where((p) => p.id != id).toList();
      await LocalCache.instance.removeFromList(CacheKeys.products, id, 'id');
    },
    offline: () async {
      _products = _products.where((p) => p.id != id).toList();
      await LocalCache.instance.removeFromList(CacheKeys.products, id, 'id');
      await SyncQueue.instance.enqueueDelete(PendingEntity.product, id);
    },
  );

  /// Cria ou atualiza um produto pra cada linha importada de uma planilha.
  /// Linhas cujo nome já existe (case-insensitive) atualizam o produto
  /// existente em vez de duplicar.
  Future<ProductImportSummary> importFromRows(
    List<ProductImportRow> rows,
  ) async {
    var created = 0;
    var updated = 0;
    final failures = <String>[];

    for (final row in rows) {
      final body = {
        'name': row.name,
        'price': row.price,
        'cost': row.cost,
        'stock': row.quantity,
      };

      Product? existing;
      for (final p in _products) {
        if (p.name.toLowerCase() == row.name.toLowerCase()) {
          existing = p;
          break;
        }
      }

      final success = existing != null
          ? await update(existing.id, body)
          : await create(body);

      if (success) {
        existing != null ? updated++ : created++;
      } else {
        failures.add(
          'Linha ${row.rowNumber} ("${row.name}"): '
          '${actionError ?? "erro desconhecido"}',
        );
      }
    }

    return ProductImportSummary(
      created: created,
      updated: updated,
      failures: failures,
    );
  }

  /// Desconta (ou soma, se `delta` for positivo) uma quantidade do estoque
  /// de um produto, permitindo que o resultado fique negativo — usado pela
  /// importação de despesas/ganhos pra refletir uma venda identificada pelo
  /// nome do produto, sem nunca bloquear a importação por falta de estoque
  /// (mesma política já adotada pra vendas feitas offline).
  Future<bool> adjustStockByDelta(String id, int delta) async {
    try {
      final updated = await ApiRoutes.updateProduct(id, {
        'stockDelta': delta,
        'allowNegativeStock': true,
      });
      _products = [
        for (final p in _products)
          if (p.id == id) updated else p,
      ];
      await LocalCache.instance.upsertInList(
        CacheKeys.products,
        updated.toJson(),
        'id',
      );
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _actionError = e.message;
      _actionErrorStatusCode = e.statusCode;
      notifyListeners();
      return false;
    }
  }

  /// Tenta `online`; se falhar por falta de conexão (não por uma rejeição de
  /// verdade do servidor), cai pra `offline`, que grava localmente e
  /// enfileira a operação pra sincronizar depois — do ponto de vista de
  /// quem chamou, a ação "funcionou" nos dois casos.
  Future<bool> _mutate({
    required Future<void> Function() online,
    required Future<void> Function() offline,
  }) async {
    _actionError = null;
    _actionErrorStatusCode = null;
    try {
      await online();
      unawaited(SyncService.instance.trySync());
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == null) {
        await offline();
        notifyListeners();
        return true;
      }
      _actionError = e.message;
      _actionErrorStatusCode = e.statusCode;
      notifyListeners();
      return false;
    }
  }
}
