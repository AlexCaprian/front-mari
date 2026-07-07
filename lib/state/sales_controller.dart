import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_routes.dart';
import '../services/dio_client.dart';
import '../services/local_cache.dart';
import '../services/local_ids.dart';
import '../services/pending_operation.dart';
import '../services/sync_queue.dart';
import '../services/sync_service.dart';

class SalesController extends ChangeNotifier {
  List<Sale> _sales = [];
  bool _isLoading = false;
  // Erro ao carregar a lista (usado pelo AsyncStateView da tela de vendas).
  String? _errorMessage;
  // true quando a lista exibida veio do cache local (API inacessível).
  bool _isOffline = false;
  // Erro de criar/editar/excluir uma venda — fica separado do erro de
  // carregamento acima para uma falha ao salvar/excluir não fazer a lista
  // inteira sumir e virar uma tela de erro.
  String? _actionError;
  int? _actionErrorStatusCode;

  SalesController() {
    SyncService.instance.addListener(_onSynced);
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSynced);
    super.dispose();
  }

  void _onSynced() {
    if (!_isLoading) load();
  }

  List<Sale> get sales => List.unmodifiable(_sales);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;
  String? get actionError => _actionError;
  int? get actionErrorStatusCode => _actionErrorStatusCode;

  Future<void> load({DateTime? startDate, DateTime? endDate}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _sales = await ApiRoutes.getSales(
        startDate: startDate?.toIso8601String(),
        endDate: endDate?.toIso8601String(),
      );
      _isOffline = false;
      unawaited(SyncService.instance.trySync());
      await LocalCache.instance.saveList(
        CacheKeys.sales,
        _sales.map((s) => s.toJson()).toList(),
      );
    } on ApiException catch (e) {
      final cached = await LocalCache.instance.readList(CacheKeys.sales);
      if (cached != null) {
        _sales = cached.map(Sale.fromJson).toList();
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
      final sale = await ApiRoutes.createSale(body);
      _sales = [sale, ..._sales];
      await LocalCache.instance.upsertInList(
        CacheKeys.sales,
        sale.toJson(),
        'id',
      );
    },
    offline: () async {
      final localId = LocalIds.generate();
      final productId = body['productId'] as String;
      final quantity = body['quantity'] as int;
      final unitPrice = (body['unitPrice'] as num).toDouble();
      final product = await _lookupCachedProduct(productId);
      final sale = Sale(
        id: localId,
        productId: productId,
        product: product,
        quantity: quantity,
        unitPrice: unitPrice,
        total: unitPrice * quantity,
        paymentMethod: paymentMethodFromApi(body['paymentMethod'] as String),
        createdAt: DateTime.now(),
      );
      _sales = [sale, ..._sales];
      await LocalCache.instance.upsertInList(
        CacheKeys.sales,
        sale.toJson(),
        'id',
      );
      await _adjustCachedProductStock(productId, -quantity);
      await SyncQueue.instance.enqueueCreate(
        PendingEntity.sale,
        localId,
        body,
      );
    },
  );

  Future<bool> update(String id, Map<String, dynamic> body) => _mutate(
    online: () async {
      final updated = await ApiRoutes.updateSale(id, body);
      _sales = [
        for (final s in _sales)
          if (s.id == id) updated else s,
      ];
      await LocalCache.instance.upsertInList(
        CacheKeys.sales,
        updated.toJson(),
        'id',
      );
    },
    offline: () async {
      Sale? existing;
      for (final s in _sales) {
        if (s.id == id) {
          existing = s;
          break;
        }
      }
      if (existing != null) {
        final newQuantity = body['quantity'] as int? ?? existing.quantity;
        final newUnitPrice =
            (body['unitPrice'] as num?)?.toDouble() ?? existing.unitPrice;
        final updated = Sale.fromJson({
          ...existing.toJson(),
          ...body,
          'total': newUnitPrice * newQuantity,
        });
        _sales = [
          for (final s in _sales)
            if (s.id == id) updated else s,
        ];
        await LocalCache.instance.upsertInList(
          CacheKeys.sales,
          updated.toJson(),
          'id',
        );
        final quantityDelta = newQuantity - existing.quantity;
        if (quantityDelta != 0) {
          await _adjustCachedProductStock(existing.productId, -quantityDelta);
        }
      }
      await SyncQueue.instance.enqueueUpdate(PendingEntity.sale, id, body);
    },
  );

  Future<bool> delete(String id) => _mutate(
    online: () async {
      await ApiRoutes.deleteSale(id);
      _sales = _sales.where((s) => s.id != id).toList();
      await LocalCache.instance.removeFromList(CacheKeys.sales, id, 'id');
    },
    offline: () async {
      Sale? existing;
      for (final s in _sales) {
        if (s.id == id) {
          existing = s;
          break;
        }
      }
      _sales = _sales.where((s) => s.id != id).toList();
      await LocalCache.instance.removeFromList(CacheKeys.sales, id, 'id');
      if (existing != null) {
        // Devolve pro estoque local a quantidade que essa venda havia
        // consumido, igual o backend faz no DELETE /sales/:id.
        await _adjustCachedProductStock(existing.productId, existing.quantity);
      }
      await SyncQueue.instance.enqueueDelete(PendingEntity.sale, id);
    },
  );

  Future<Product?> _lookupCachedProduct(String productId) async {
    final cached = await LocalCache.instance.readList(CacheKeys.products);
    if (cached == null) return null;
    for (final json in cached) {
      if (json['id'] == productId) return Product.fromJson(json);
    }
    return null;
  }

  /// Ajusta o estoque do produto direto no cache local (sem depender de uma
  /// referência ao [ProductsController], pra manter os controllers
  /// desacoplados) — é só uma aproximação enquanto offline: assim que a
  /// sincronização trouxer os números reais do servidor, ela se autocorrige.
  Future<void> _adjustCachedProductStock(String productId, int delta) async {
    final cached = await LocalCache.instance.readList(CacheKeys.products);
    if (cached == null) return;
    final next = [
      for (final json in cached)
        if (json['id'] == productId)
          {...json, 'stock': (json['stock'] as int) + delta}
        else
          json,
    ];
    await LocalCache.instance.saveList(CacheKeys.products, next);
  }

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
