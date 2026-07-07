import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_routes.dart';
import '../services/dio_client.dart';
import '../services/local_cache.dart';
import '../utils/month_utils.dart';

class ReportsController extends ChangeNotifier {
  MonthlyReport? _monthlyReport;
  bool _isLoadingMonthly = false;
  String? _monthlyError;
  bool _isMonthlyOffline = false;

  List<Transaction>? _monthlyExpenses;
  bool _isLoadingMonthlyExpenses = false;
  String? _monthlyExpensesError;
  bool _isMonthlyExpensesOffline = false;

  List<MonthComparison>? _comparison;
  bool _isLoadingComparison = false;
  String? _comparisonError;
  bool _isComparisonOffline = false;

  MonthlyReport? get monthlyReport => _monthlyReport;
  bool get isLoadingMonthly => _isLoadingMonthly;
  String? get monthlyError => _monthlyError;
  bool get isMonthlyOffline => _isMonthlyOffline;

  List<Transaction>? get monthlyExpenses => _monthlyExpenses;
  bool get isLoadingMonthlyExpenses => _isLoadingMonthlyExpenses;
  String? get monthlyExpensesError => _monthlyExpensesError;
  bool get isMonthlyExpensesOffline => _isMonthlyExpensesOffline;

  List<MonthComparison>? get comparison => _comparison;
  bool get isLoadingComparison => _isLoadingComparison;
  String? get comparisonError => _comparisonError;
  bool get isComparisonOffline => _isComparisonOffline;

  Future<void> loadMonthly({String? month}) async {
    _isLoadingMonthly = true;
    _monthlyError = null;
    notifyListeners();
    try {
      _monthlyReport = await ApiRoutes.getMonthlyReport(month: month);
      _isMonthlyOffline = false;
      await LocalCache.instance.saveObject(
        CacheKeys.monthlyReport,
        _monthlyReport!.toCacheJson(),
      );
    } on ApiException catch (e) {
      final cached = await LocalCache.instance.readObject(
        CacheKeys.monthlyReport,
      );
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

  /// Lista de despesas (transações do tipo `expense`) do mês selecionado,
  /// pra exibir no Relatório Mensal no mesmo formato de item usado em
  /// "Últimas movimentações" — complementa o resumo por categoria já
  /// mostrado ali com o detalhe de cada lançamento individual.
  Future<void> loadMonthlyExpenses(String month) async {
    _isLoadingMonthlyExpenses = true;
    _monthlyExpensesError = null;
    notifyListeners();
    final range = monthDateRangeUtc(month);
    try {
      _monthlyExpenses = await ApiRoutes.getTransactions(
        startDate: range.start.toIso8601String(),
        endDate: range.end.toIso8601String(),
        type: TransactionType.expense.apiValue,
      );
      _monthlyExpenses!.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      _isMonthlyExpensesOffline = false;
    } on ApiException catch (e) {
      // Sem conexão: filtra o mês pedido a partir do cache de transações já
      // mantido pelo TransactionsController (que já reflete mutações feitas
      // offline), em vez de simplesmente mostrar erro.
      final cached = await LocalCache.instance.readList(
        CacheKeys.transactions,
      );
      if (cached != null) {
        _monthlyExpenses =
            cached
                .map(Transaction.fromJson)
                .where(
                  (t) =>
                      t.type == TransactionType.expense &&
                      !t.occurredAt.isBefore(range.start) &&
                      t.occurredAt.isBefore(range.end),
                )
                .toList()
              ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        _isMonthlyExpensesOffline = true;
      } else {
        _monthlyExpensesError = e.message;
      }
    } finally {
      _isLoadingMonthlyExpenses = false;
      notifyListeners();
    }
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
