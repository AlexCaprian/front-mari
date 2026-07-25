import 'local_cache.dart';
import 'local_ids.dart';
import 'pending_operation.dart';

/// Fila persistida (ordem cronológica/FIFO) de ações feitas offline,
/// aguardando serem replicadas no servidor pelo [SyncService]. Nunca duplica
/// dados: editar ou excluir um item que ainda nem foi sincronizado funde na
/// própria operação de criação (ou edição) já enfileirada, em vez de virar
/// uma entrada nova.
class SyncQueue {
  SyncQueue._internal();

  static final SyncQueue instance = SyncQueue._internal();

  Future<List<PendingOperation>> readAll() async {
    final raw = await LocalCache.instance.readList(
      CacheKeys.pendingOperations,
    );
    if (raw == null) return [];
    return raw.map(PendingOperation.fromJson).toList();
  }

  Future<void> _saveAll(List<PendingOperation> ops) => LocalCache.instance
      .saveList(CacheKeys.pendingOperations, ops.map((o) => o.toJson()).toList());

  Future<void> enqueueCreate(
    PendingEntity entity,
    String localId,
    Map<String, dynamic> body,
  ) async {
    final ops = await readAll();
    ops.add(
      PendingOperation(
        opId: LocalIds.generate(),
        entity: entity,
        op: PendingOp.create,
        targetId: localId,
        body: body,
      ),
    );
    await _saveAll(ops);
  }

  /// Se `targetId` ainda não foi sincronizado (tem uma `create`/`update`
  /// pendente na fila), mescla `patch` nessa mesma operação em vez de
  /// enfileirar uma nova.
  Future<void> enqueueUpdate(
    PendingEntity entity,
    String targetId,
    Map<String, dynamic> patch,
  ) async {
    final ops = await readAll();
    final index = ops.indexWhere(
      (o) =>
          o.entity == entity &&
          o.targetId == targetId &&
          (o.op == PendingOp.create || o.op == PendingOp.update),
    );
    if (index == -1) {
      ops.add(
        PendingOperation(
          opId: LocalIds.generate(),
          entity: entity,
          op: LocalIds.isLocal(targetId)
              ? PendingOp.create
              : PendingOp.update,
          targetId: targetId,
          body: patch,
        ),
      );
    } else {
      final existing = ops[index];
      ops[index] = existing.copyWith(body: {...?existing.body, ...patch});
    }
    await _saveAll(ops);
  }

  /// Se `targetId` for um id local (nunca existiu no servidor), remove a
  /// criação (e qualquer edição mesclada) da fila sem nunca tocar a rede.
  Future<void> enqueueDelete(PendingEntity entity, String targetId) async {
    final ops = await readAll();
    if (LocalIds.isLocal(targetId)) {
      ops.removeWhere((o) => o.entity == entity && o.targetId == targetId);
    } else {
      ops.removeWhere(
        (o) =>
            o.entity == entity &&
            o.targetId == targetId &&
            o.op == PendingOp.update,
      );
      ops.add(
        PendingOperation(
          opId: LocalIds.generate(),
          entity: entity,
          op: PendingOp.delete,
          targetId: targetId,
        ),
      );
    }
    await _saveAll(ops);
  }

  Future<void> removeOp(String opId) async {
    final ops = await readAll();
    ops.removeWhere((o) => o.opId == opId);
    await _saveAll(ops);
  }

  /// Resolve um id (local ou real) pro id real mais atual conhecido — usado
  /// antes de mandar qualquer operação pro servidor.
  Future<String> resolveId(String id) async {
    if (!LocalIds.isLocal(id)) return id;
    final map = await _readRemap();
    return map[id] ?? id;
  }

  Future<void> recordRemap(String localId, String realId) async {
    final map = await _readRemap();
    map[localId] = realId;
    await LocalCache.instance.saveObject(CacheKeys.idRemap, map);
  }

  Future<Map<String, String>> _readRemap() async {
    final raw = await LocalCache.instance.readObject(CacheKeys.idRemap);
    if (raw == null) return {};
    return raw.map((key, value) => MapEntry(key, value as String));
  }

  /// Guarda o registro de uma operação que não pôde ser sincronizada (rejeição
  /// real do servidor, não falta de conexão) — lista limitada, só pra não
  /// perder o rastro completamente.
  Future<void> appendSyncIssue(Map<String, dynamic> issue) async {
    final current =
        await LocalCache.instance.readList(CacheKeys.syncIssues) ?? [];
    final next = [...current, issue];
    final capped = next.length > 20
        ? next.sublist(next.length - 20)
        : next;
    await LocalCache.instance.saveList(CacheKeys.syncIssues, capped);
  }

  /// Limpa toda a fila/remap/issues — usado no logout, pra uma sessão não
  /// tentar sincronizar pendências de outra conta.
  Future<void> clear() async {
    await LocalCache.instance.saveList(CacheKeys.pendingOperations, []);
    await LocalCache.instance.saveObject(CacheKeys.idRemap, {});
    await LocalCache.instance.saveList(CacheKeys.syncIssues, []);
  }
}
