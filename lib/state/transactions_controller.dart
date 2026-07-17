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

class TransactionsController extends ChangeNotifier {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  // Erro ao carregar a lista (usado pelo AsyncStateView da tela de transações).
  String? _errorMessage;
  // true quando a lista exibida veio do cache local (API inacessível).
  bool _isOffline = false;
  // Erro de criar/editar/excluir uma transação — fica separado do erro de
  // carregamento acima para uma falha ao salvar/excluir não fazer a lista
  // inteira sumir e virar uma tela de erro.
  String? _actionError;
  int? _actionErrorStatusCode;

  TransactionsController() {
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

  List<Transaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;
  String? get actionError => _actionError;
  int? get actionErrorStatusCode => _actionErrorStatusCode;

  Future<void> load({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _transactions = await ApiRoutes.getTransactions(
        startDate: startDate?.toIso8601String(),
        endDate: endDate?.toIso8601String(),
        type: type?.apiValue,
      );
      _isOffline = false;
      unawaited(SyncService.instance.trySync());
      await LocalCache.instance.saveList(
        CacheKeys.transactions,
        _transactions.map((t) => t.toJson()).toList(),
      );
    } on ApiException catch (e) {
      final cached = await LocalCache.instance.readList(
        CacheKeys.transactions,
      );
      if (cached != null) {
        _transactions = cached.map(Transaction.fromJson).toList();
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
      final transaction = await ApiRoutes.createTransaction(body);
      _transactions = [transaction, ..._transactions];
      await LocalCache.instance.upsertInList(
        CacheKeys.transactions,
        transaction.toJson(),
        'id',
      );
    },
    offline: () async {
      final localId = LocalIds.generate();
      final transaction = Transaction(
        id: localId,
        type: transactionTypeFromApi(body['type'] as String),
        amount: (body['amount'] as num).toDouble(),
        category: body['category'] as String,
        occurredAt: DateTime.parse(body['occurredAt'] as String).toLocal(),
        createdAt: DateTime.now(),
      );
      _transactions = [transaction, ..._transactions];
      await LocalCache.instance.upsertInList(
        CacheKeys.transactions,
        transaction.toJson(),
        'id',
      );
      await SyncQueue.instance.enqueueCreate(
        PendingEntity.transaction,
        localId,
        body,
      );
    },
  );

  Future<bool> update(String id, Map<String, dynamic> body) => _mutate(
    online: () async {
      final updated = await ApiRoutes.updateTransaction(id, body);
      _transactions = [
        for (final t in _transactions)
          if (t.id == id) updated else t,
      ];
      await LocalCache.instance.upsertInList(
        CacheKeys.transactions,
        updated.toJson(),
        'id',
      );
    },
    offline: () async {
      Transaction? existing;
      for (final t in _transactions) {
        if (t.id == id) {
          existing = t;
          break;
        }
      }
      if (existing != null) {
        final updated = Transaction.fromJson({...existing.toJson(), ...body});
        _transactions = [
          for (final t in _transactions)
            if (t.id == id) updated else t,
        ];
        await LocalCache.instance.upsertInList(
          CacheKeys.transactions,
          updated.toJson(),
          'id',
        );
      }
      await SyncQueue.instance.enqueueUpdate(
        PendingEntity.transaction,
        id,
        body,
      );
    },
  );

  Future<bool> delete(String id) => _mutate(
    online: () async {
      await ApiRoutes.deleteTransaction(id);
      _transactions = _transactions.where((t) => t.id != id).toList();
      await LocalCache.instance.removeFromList(
        CacheKeys.transactions,
        id,
        'id',
      );
    },
    offline: () async {
      _transactions = _transactions.where((t) => t.id != id).toList();
      await LocalCache.instance.removeFromList(
        CacheKeys.transactions,
        id,
        'id',
      );
      await SyncQueue.instance.enqueueDelete(PendingEntity.transaction, id);
    },
  );

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
