enum PendingEntity { product, sale, transaction }

enum PendingOp { create, update, delete }

/// Uma ação (criar/editar/excluir) feita offline, guardada pra ser replicada
/// no servidor assim que a conexão voltar. Ver [SyncQueue] pras regras de
/// como isso é enfileirado/mesclado.
class PendingOperation {
  const PendingOperation({
    required this.opId,
    required this.entity,
    required this.op,
    required this.targetId,
    this.body,
  });

  /// Id próprio dessa entrada da fila (não é o id da entidade).
  final String opId;
  final PendingEntity entity;
  final PendingOp op;

  /// Id do produto/venda/transação afetado — pode ser um id local
  /// ([LocalIds.isLocal]) até essa (ou uma operação anterior na fila) ser
  /// sincronizada.
  final String targetId;

  /// Corpo da requisição (nulo pra `delete`).
  final Map<String, dynamic>? body;

  PendingOperation copyWith({Map<String, dynamic>? body}) => PendingOperation(
    opId: opId,
    entity: entity,
    op: op,
    targetId: targetId,
    body: body ?? this.body,
  );

  Map<String, dynamic> toJson() => {
    'opId': opId,
    'entity': entity.name,
    'op': op.name,
    'targetId': targetId,
    'body': body,
  };

  factory PendingOperation.fromJson(Map<String, dynamic> json) =>
      PendingOperation(
        opId: json['opId'] as String,
        entity: PendingEntity.values.byName(json['entity'] as String),
        op: PendingOp.values.byName(json['op'] as String),
        targetId: json['targetId'] as String,
        body: (json['body'] as Map?)?.cast<String, dynamic>(),
      );
}
