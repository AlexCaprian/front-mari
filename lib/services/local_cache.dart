import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Chaves usadas pelo [LocalCache] — uma por tipo de dado guardado.
class CacheKeys {
  static const products = 'cache_products';
  static const sales = 'cache_sales';
  static const transactions = 'cache_transactions';
  static const dashboard = 'cache_dashboard';
  static const monthlyReport = 'cache_monthly_report';
  static const monthComparison = 'cache_month_comparison';

  /// Fila de ações (criar/editar/excluir) feitas offline, aguardando
  /// sincronização — ver [SyncQueue].
  static const pendingOperations = 'cache_pending_operations';

  /// Mapa persistido de id local -> id real, preenchido conforme a
  /// sincronização confirma cada criação feita offline.
  static const idRemap = 'cache_id_remap';

  /// Lista limitada de operações que não puderam ser sincronizadas (rejeição
  /// real do servidor, não falta de conexão) — só pra não perder o rastro.
  static const syncIssues = 'cache_sync_issues';
}

/// Cache local simples (JSON em SharedPreferences) usado como fallback
/// quando a API está inacessível: cada controller salva aqui a última
/// resposta boa do servidor e lê de volta quando um `load()` falha por
/// falta de conexão. Sempre substitui ou faz upsert/remove por id — nunca
/// duplica registros.
class LocalCache {
  LocalCache._internal();

  static final LocalCache instance = LocalCache._internal();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _prefsInstance async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Guarda uma lista de registros substituindo inteiramente o que estava
  /// salvo antes — usado depois de um `load()` bem-sucedido, já que a
  /// resposta da API é sempre a verdade mais recente.
  Future<void> saveList(String key, List<Map<String, dynamic>> items) async {
    final prefs = await _prefsInstance;
    await prefs.setString(key, jsonEncode(items));
  }

  Future<List<Map<String, dynamic>>?> readList(String key) async {
    final prefs = await _prefsInstance;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as List;
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Insere ou substitui (por id) um item dentro de uma lista já cacheada —
  /// usado depois de criar/editar um registro com sucesso.
  Future<void> upsertInList(
    String key,
    Map<String, dynamic> item,
    String idField,
  ) async {
    final current = await readList(key) ?? [];
    final id = item[idField];
    final next = [
      for (final existing in current)
        if (existing[idField] != id) existing,
      item,
    ];
    await saveList(key, next);
  }

  /// Remove um item (por id) de uma lista já cacheada — usado depois de
  /// excluir um registro com sucesso.
  Future<void> removeFromList(String key, String id, String idField) async {
    final current = await readList(key);
    if (current == null) return;
    await saveList(key, [
      for (final existing in current)
        if (existing[idField] != id) existing,
    ]);
  }

  Future<void> saveObject(String key, Map<String, dynamic> data) async {
    final prefs = await _prefsInstance;
    await prefs.setString(key, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> readObject(String key) async {
    final prefs = await _prefsInstance;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
