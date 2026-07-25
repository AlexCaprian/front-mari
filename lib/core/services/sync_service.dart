import 'package:flutter/foundation.dart';

import 'api_routes.dart';
import 'dio_client.dart';
import 'pending_operation.dart';
import 'sync_queue.dart';

/// Drena a [SyncQueue], replicando no servidor cada ação feita offline. Não
/// há um listener de conectividade em background — isso é chamado de forma
/// "oportunista" nos pontos onde o app já toca a rede com sucesso (abrir uma
/// tela, puxar pra atualizar, criar/editar/excluir algo com sucesso).
/// Notifica os listeners quando o drain sincroniza ou descarta algo, pra
/// controllers recarregarem e trocarem ids locais pelos reais.
class SyncService extends ChangeNotifier {
  SyncService._internal();

  static final SyncService instance = SyncService._internal();

  bool _isSyncing = false;

  Future<void> trySync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    bool changed;
    try {
      changed = await _drain();
    } finally {
      _isSyncing = false;
    }
    if (changed) notifyListeners();
  }

  Future<bool> _drain() async {
    final ops = await SyncQueue.instance.readAll();
    if (ops.isEmpty) return false;

    var changed = false;
    final droppedLocalIds = <String>{};

    for (final op in ops) {
      if (op.entity == PendingEntity.sale && op.op == PendingOp.create) {
        final productId = op.body?['productId'] as String?;
        if (productId != null && droppedLocalIds.contains(productId)) {
          await _dropOp(
            op,
            'Produto referenciado nesta venda não pôde ser sincronizado.',
          );
          droppedLocalIds.add(op.targetId);
          changed = true;
          continue;
        }
      }

      try {
        final realId = await _execute(op);
        if (op.op == PendingOp.create && realId != null) {
          await SyncQueue.instance.recordRemap(op.targetId, realId);
        }
        await SyncQueue.instance.removeOp(op.opId);
        changed = true;
      } on ApiException catch (e) {
        if (e.statusCode == null) {
          // Falta de conexão de novo: para o drain, mantém o resto da fila
          // pra tentar depois.
          break;
        }
        // Rejeição real do servidor (não dá pra tentar de novo): descarta
        // só essa operação e segue com o resto da fila.
        await _dropOp(op, e.message, statusCode: e.statusCode);
        if (op.op == PendingOp.create) droppedLocalIds.add(op.targetId);
        changed = true;
      }
    }

    return changed;
  }

  Future<void> _dropOp(
    PendingOperation op,
    String message, {
    int? statusCode,
  }) async {
    await SyncQueue.instance.appendSyncIssue({
      'entity': op.entity.name,
      'op': op.op.name,
      'targetId': op.targetId,
      'message': message,
      'statusCode': statusCode,
      'failedAt': DateTime.now().toIso8601String(),
    });
    await SyncQueue.instance.removeOp(op.opId);
  }

  /// Executa uma operação no servidor. Devolve o id real quando `op` é uma
  /// criação (pra registrar o remap), ou `null` pra update/delete.
  Future<String?> _execute(PendingOperation op) {
    switch (op.entity) {
      case PendingEntity.product:
        return _executeProduct(op);
      case PendingEntity.sale:
        return _executeSale(op);
      case PendingEntity.transaction:
        return _executeTransaction(op);
    }
  }

  Future<String?> _executeProduct(PendingOperation op) async {
    switch (op.op) {
      case PendingOp.create:
        final product = await ApiRoutes.createProduct(op.body!);
        return product.id;
      case PendingOp.update:
        final id = await SyncQueue.instance.resolveId(op.targetId);
        await ApiRoutes.updateProduct(id, op.body!);
        return null;
      case PendingOp.delete:
        final id = await SyncQueue.instance.resolveId(op.targetId);
        await ApiRoutes.deleteProduct(id);
        return null;
    }
  }

  Future<String?> _executeSale(PendingOperation op) async {
    switch (op.op) {
      case PendingOp.create:
        final body = Map<String, dynamic>.from(op.body!);
        body['productId'] = await SyncQueue.instance.resolveId(
          body['productId'] as String,
        );
        // Só a sincronização de uma venda feita offline pode deixar o
        // estoque negativo — nunca as chamadas normais do app online, que
        // continuam bloqueando por falta de estoque como antes.
        body['allowNegativeStock'] = true;
        final sale = await ApiRoutes.createSale(body);
        return sale.id;
      case PendingOp.update:
        final id = await SyncQueue.instance.resolveId(op.targetId);
        final body = Map<String, dynamic>.from(
          op.body!,
        )..['allowNegativeStock'] = true;
        await ApiRoutes.updateSale(id, body);
        return null;
      case PendingOp.delete:
        final id = await SyncQueue.instance.resolveId(op.targetId);
        await ApiRoutes.deleteSale(id);
        return null;
    }
  }

  Future<String?> _executeTransaction(PendingOperation op) async {
    switch (op.op) {
      case PendingOp.create:
        final transaction = await ApiRoutes.createTransaction(op.body!);
        return transaction.id;
      case PendingOp.update:
        final id = await SyncQueue.instance.resolveId(op.targetId);
        await ApiRoutes.updateTransaction(id, op.body!);
        return null;
      case PendingOp.delete:
        final id = await SyncQueue.instance.resolveId(op.targetId);
        await ApiRoutes.deleteTransaction(id);
        return null;
    }
  }
}
