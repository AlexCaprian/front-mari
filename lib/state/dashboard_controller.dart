import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_routes.dart';
import '../services/dio_client.dart';
import '../services/local_cache.dart';
import '../services/sync_queue.dart';
import '../services/sync_service.dart';
import '../utils/dashboard_activity_builder.dart';

class DashboardController extends ChangeNotifier {
  DashboardData? _data;
  bool _isLoading = false;
  String? _errorMessage;
  // true quando os dados exibidos vieram do cache local (API inacessível).
  bool _isOffline = false;

  DashboardController() {
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

  DashboardData? get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;

  Future<void> load({String? month}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _data = await ApiRoutes.getDashboard(month: month);
      _isOffline = false;
      unawaited(SyncService.instance.trySync());

      final pending = await SyncQueue.instance.readAll();
      if (pending.isEmpty) {
        // Nenhuma mutação offline pendente: a resposta do servidor já é a
        // verdade mais recente.
        await LocalCache.instance.saveObject(
          CacheKeys.dashboard,
          _data!.toCacheJson(),
        );
      } else {
        // Ainda há algo que o servidor não sabe (feito offline) — mostra o
        // recomputo local em vez da resposta, que já está desatualizada.
        final rebuilt = await _buildFromLocalCache(month);
        if (rebuilt != null) _data = rebuilt;
      }
    } on ApiException catch (e) {
      final rebuilt = await _buildFromLocalCache(month);
      if (rebuilt != null) {
        _data = rebuilt;
        _isOffline = true;
      } else {
        final cached = await LocalCache.instance.readObject(
          CacheKeys.dashboard,
        );
        if (cached != null) {
          _data = DashboardData.fromCacheJson(cached);
          _isOffline = true;
        } else {
          _errorMessage = e.message;
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reconstrói o dashboard a partir das vendas/transações já cacheadas
  /// (que refletem mutações offline, ao contrário do blob congelado de
  /// `CacheKeys.dashboard`). Devolve `null` se nunca houve nada cacheado
  /// (ex.: primeiro uso do app sem nunca ter conectado).
  Future<DashboardData?> _buildFromLocalCache(String? month) async {
    final sales = await LocalCache.instance.readList(CacheKeys.sales);
    final transactions = await LocalCache.instance.readList(
      CacheKeys.transactions,
    );
    if (sales == null && transactions == null) return null;
    return buildDashboardDataFromCache(
      sales: (sales ?? []).map(Sale.fromJson).toList(),
      transactions: (transactions ?? []).map(Transaction.fromJson).toList(),
      month: month,
    );
  }
}
