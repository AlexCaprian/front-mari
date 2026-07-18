import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_routes.dart';
import '../services/dio_client.dart';
import '../services/local_cache.dart';
import '../services/session_events.dart';
import '../services/sync_queue.dart';
import '../services/sync_service.dart';
import '../utils/dashboard_activity_builder.dart';
import '../utils/month_utils.dart';

class DashboardController extends ChangeNotifier {
  DashboardData? _data;
  bool _isLoading = false;
  String? _errorMessage;
  // true quando os dados exibidos vieram do cache local (API inacessível).
  bool _isOffline = false;

  DashboardController() {
    SyncService.instance.addListener(_onSynced);
    SessionEvents.instance.addListener(_onSessionEnded);
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSynced);
    SessionEvents.instance.removeListener(_onSessionEnded);
    super.dispose();
  }

  void _onSynced() {
    if (!_isLoading) load();
  }

  // Sessão encerrada (logout ou token expirado): limpa o estado em memória
  // pra não continuar mostrando o dashboard da conta anterior.
  void _onSessionEnded() {
    _data = null;
    _isLoading = false;
    _errorMessage = null;
    _isOffline = false;
    notifyListeners();
  }

  DashboardData? get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;

  Future<void> load({String? month}) async {
    // Sem mês explícito (ex: aba Início), usa o mês atual local em vez de
    // deixar o backend cair no dele (calculado em UTC — diverge do mês local
    // nas últimas horas do último dia do mês em fusos atrás de UTC).
    final effectiveMonth = month ?? currentMonthLocal();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // O `activity` de GET /dashboard vem limitado a 10 itens pelo backend
      // (back_mari/src/routes/dashboard.routes.ts). Pra mostrar o mês
      // inteiro em "Últimas movimentações", buscamos vendas/transações do
      // mês à parte (essas rotas não têm esse limite) e montamos a lista
      // completa, aproveitando só os totais (já corretos) do /dashboard.
      final bounds = monthDateRangeUtc(effectiveMonth);
      final endDateInclusive = bounds.end.subtract(
        const Duration(milliseconds: 1),
      );
      final dashboardFuture = ApiRoutes.getDashboard(month: effectiveMonth);
      final salesFuture = ApiRoutes.getSales(
        startDate: bounds.start.toIso8601String(),
        endDate: endDateInclusive.toIso8601String(),
      );
      final transactionsFuture = ApiRoutes.getTransactions(
        startDate: bounds.start.toIso8601String(),
        endDate: endDateInclusive.toIso8601String(),
      );
      final dashboard = await dashboardFuture;
      final sales = await salesFuture;
      final transactions = await transactionsFuture;

      _data = DashboardData(
        month: dashboard.month,
        saldoDoMes: dashboard.saldoDoMes,
        ganhos: dashboard.ganhos,
        despesas: dashboard.despesas,
        activity: buildActivityList(sales: sales, transactions: transactions),
      );
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
        final rebuilt = await _buildFromLocalCache(effectiveMonth);
        if (rebuilt != null) _data = rebuilt;
      }
    } on ApiException catch (e) {
      final rebuilt = await _buildFromLocalCache(effectiveMonth);
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
