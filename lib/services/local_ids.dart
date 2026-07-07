import 'dart:math';

/// Ids temporários usados por itens criados offline, antes de existir um id
/// real do servidor. O backend rejeita qualquer id não-numérico com 400
/// (`BigInt(raw)` falha), então um id local nunca é aceito por engano caso
/// algo vaze pra rede antes de ser resolvido pela sincronização.
class LocalIds {
  LocalIds._();

  static const prefix = 'local_';
  static final _random = Random();

  static String generate() =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(0x7fffffff)}';

  static bool isLocal(String id) => id.startsWith(prefix);
}
