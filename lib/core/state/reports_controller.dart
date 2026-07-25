import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_routes.dart';
import '../services/dio_client.dart';
import '../services/local_cache.dart';
import '../services/session_events.dart';
import '../utils/dashboard_activity_builder.dart';
import '../utils/month_utils.dart';

class ReportsController extends ChangeNotifier {
  ReportsController() {
    SessionEvents.instance.addListener(_onSessionEnded);
  }

  @override
  void dispose() {
    SessionEvents.instance.removeListener(_onSessionEnded);
    super.dispose();
  }

  // Sessão encerrada (logout ou token expirado): limpa o estado em memória
  // pra não continuar mostrando relatórios da conta anterior.
  void _onSessionEnded() {
    _monthlyReport = null;
    _isLoadingMonthly = false;
    _monthlyError = null;
    _isMonthlyOffline = false;
    _monthlyActivity = null;
    _isLoadingMonthlyActivity = false;
    _monthlyActivityError = null;
    _isMonthlyActivityOffline = false;
    _comparison = null;
    _isLoadingComparison = false;
    _comparisonError = null;
    _isComparisonOffline = false;
    notifyListeners();
  }

  MonthlyReport? _monthlyReport;
  bool _isLoadingMonthly = false;
  String? _monthlyError;
  bool _isMonthlyOffline = false;

  List<DashboardActivity>? _monthlyActivity;
  bool _isLoadingMonthlyActivity = false;
  String? _monthlyActivityError;
  bool _isMonthlyActivityOffline = false;

  List<MonthComparison>? _comparison;
  bool _isLoadingComparison = false;
  String? _comparisonError;
  bool _isComparisonOffline = false;

  MonthlyReport? get monthlyReport => _monthlyReport;
  bool get isLoadingMonthly => _isLoadingMonthly;
  String? get monthlyError => _monthlyError;
  bool get isMonthlyOffline => _isMonthlyOffline;

  List<DashboardActivity>? get monthlyActivity => _monthlyActivity;
  bool get isLoadingMonthlyActivity => _isLoadingMonthlyActivity;
  String? get monthlyActivityError => _monthlyActivityError;
  bool get isMonthlyActivityOffline => _isMonthlyActivityOffline;

  List<MonthComparison>? get comparison => _comparison;
  bool get isLoadingComparison => _isLoadingComparison;
  String? get comparisonError => _comparisonError;
  bool get isComparisonOffline => _isComparisonOffline;

  Future<void> loadMonthly({String? month}) async {
    _isLoadingMonthly = true;
    _monthlyError = null;
    notifyListeners();

    final cached = await LocalCache.instance.readObject(
      CacheKeys.monthlyReport,
    );
    // Cache-first: pinta o relatório salvo na hora — mas só se for do mesmo
    // mês pedido, senão piscaria os números de outro mês (o cache é um blob
    // único, não por mês). Quando o mês não é informado, não arrisca.
    if (cached != null && month != null && cached['month'] == month) {
      _monthlyReport = MonthlyReport.fromCacheJson(cached);
      _isLoadingMonthly = false;
      notifyListeners();
    }

    try {
      _monthlyReport = await ApiRoutes.getMonthlyReport(month: month);
      _isMonthlyOffline = false;
      await LocalCache.instance.saveObject(
        CacheKeys.monthlyReport,
        _monthlyReport!.toCacheJson(),
      );
    } on ApiException catch (e) {
      // Offline: mostra o relatório em cache mesmo que seja de outro mês (é
      // melhor que uma tela de erro); só não há o que mostrar se nunca houve
      // cache.
      if (cached != null) {
        _monthlyReport = MonthlyReport.fromCacheJson(cached);
        _isMonthlyOffline = true;
      } else {
        _monthlyError = e.message;
      }
    } finally {
      _isLoadingMonthly = false;
      notifyListeners();
    }
  }

  /// Lista de movimentações (vendas + transações, ganhos e despesas) do mês
  /// selecionado, pra exibir no Relatório Mensal no mesmo formato e com os
  /// mesmos filtros usados em "Últimas movimentações" do Início.
  Future<void> loadMonthlyActivity(String month) async {
    _isLoadingMonthlyActivity = true;
    _monthlyActivityError = null;
    notifyListeners();

    // Cache-first: monta as movimentações do mês a partir do cache local (se
    // houver) e mostra na hora, pra tela não ficar num spinner esperando a
    // API. O filtro por mês garante que o cache exibido é sempre do mês pedido.
    final cachedActivity = await _readCachedMonthlyActivity(month);
    if (cachedActivity != null) {
      _monthlyActivity = cachedActivity;
      _isLoadingMonthlyActivity = false;
      notifyListeners();
    }

    final range = monthDateRangeUtc(month);
    final endDateInclusive = range.end.subtract(
      const Duration(milliseconds: 1),
    );
    try {
      final sales = await ApiRoutes.getSales(
        startDate: range.start.toIso8601String(),
        endDate: endDateInclusive.toIso8601String(),
      );
      final transactions = await ApiRoutes.getTransactions(
        startDate: range.start.toIso8601String(),
        endDate: endDateInclusive.toIso8601String(),
      );
      _monthlyActivity = buildActivityList(
        sales: sales,
        transactions: transactions,
      );
      _isMonthlyActivityOffline = false;
      // Garante um fallback offline das vendas/transações do mês se ainda não
      // houver cache — sem sobrescrever um já existente (outros meses ou
      // mutações offline pendentes).
      await LocalCache.instance.saveListIfAbsent(
        CacheKeys.sales,
        sales.map((s) => s.toJson()).toList(),
      );
      await LocalCache.instance.saveListIfAbsent(
        CacheKeys.transactions,
        transactions.map((t) => t.toJson()).toList(),
      );
    } on ApiException catch (e) {
      // Sem conexão: mantém as movimentações já montadas do cache (acima); só
      // não há o que mostrar se nunca houve nada cacheado.
      if (cachedActivity != null) {
        _monthlyActivity = cachedActivity;
        _isMonthlyActivityOffline = true;
      } else {
        _monthlyActivityError = e.message;
      }
    } finally {
      _isLoadingMonthlyActivity = false;
      notifyListeners();
    }
  }

  /// Monta as movimentações do mês a partir do cache local de vendas e
  /// transações (que já reflete mutações feitas offline), filtrando pelo mês
  /// pedido. Devolve `null` se nunca houve nada cacheado.
  Future<List<DashboardActivity>?> _readCachedMonthlyActivity(
    String month,
  ) async {
    final range = monthDateRangeUtc(month);
    final cachedSales = await LocalCache.instance.readList(CacheKeys.sales);
    final cachedTransactions = await LocalCache.instance.readList(
      CacheKeys.transactions,
    );
    if (cachedSales == null && cachedTransactions == null) return null;
    bool inMonth(DateTime date) =>
        !date.isBefore(range.start) && date.isBefore(range.end);
    final sales = (cachedSales ?? [])
        .map(Sale.fromJson)
        .where((s) => inMonth(s.createdAt))
        .toList();
    final transactions = (cachedTransactions ?? [])
        .map(Transaction.fromJson)
        .where((t) => inMonth(t.occurredAt))
        .toList();
    return buildActivityList(sales: sales, transactions: transactions);
  }

  Future<void> loadComparison(List<String> months) async {
    _isLoadingComparison = true;
    _comparisonError = null;
    notifyListeners();
    try {
      _comparison = await ApiRoutes.compareMonths(months);
      _isComparisonOffline = false;
      await LocalCache.instance.saveObject(CacheKeys.monthComparison, {
        'months': _comparison!.map((c) => c.toCacheJson()).toList(),
      });
    } on ApiException catch (e) {
      final cached = await LocalCache.instance.readObject(
        CacheKeys.monthComparison,
      );
      if (cached != null) {
        _comparison = (cached['months'] as List)
            .map((e) => MonthComparison.fromJson(e as Map<String, dynamic>))
            .toList();
        _isComparisonOffline = true;
      } else {
        _comparisonError = e.message;
      }
    } finally {
      _isLoadingComparison = false;
      notifyListeners();
    }
  }
}
