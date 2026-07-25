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
  // true durante todo o load() (cache + rede). Diferente de _isLoading, que
  // vira false assim que o cache é pintado (cache-first): impede um sync em
  // segundo plano de disparar um load() concorrente com a rede ainda em voo.
  bool _isFetching = false;
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
    if (!_isFetching) load();
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
    // Evita loads sobrepostos (ex.: sync em segundo plano disparando load()
    // enquanto a rede do load anterior ainda não voltou).
    if (_isFetching) return;
    // Sem mês explícito (ex: aba Início), usa o mês atual local em vez de
    // deixar o backend cair no dele (calculado em UTC — diverge do mês local
    // nas últimas horas do último dia do mês em fusos atrás de UTC).
    final effectiveMonth = month ?? currentMonthLocal();
    _isFetching = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Cache-first: mostra na hora a melhor versão local do mês (se houver),
    // pra tela não ficar num spinner enquanto a API responde. A resposta da
    // rede abaixo substitui isso assim que chegar.
    final cachedData = await _readCachedDashboard(effectiveMonth);
    if (cachedData != null) {
      _data = cachedData;
      _isLoading = false;
      notifyListeners();
    }

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

      // Início busca vendas/transações do mês só pra montar as movimentações,
      // mas essas telas de detalhe podem nunca ter sido abertas — então
      // garante um fallback offline salvando-as se ainda não houver cache.
      // Não sobrescreve um cache existente (pode ter outros meses ou mutações
      // offline pendentes) graças ao saveListIfAbsent.
      await LocalCache.instance.saveListIfAbsent(
        CacheKeys.sales,
        sales.map((s) => s.toJson()).toList(),
      );
      await LocalCache.instance.saveListIfAbsent(
        CacheKeys.transactions,
        transactions.map((t) => t.toJson()).toList(),
      );

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
      // Sem conexão: se já temos uma versão em cache (pintada acima), mantém e
      // só marca offline; senão, não há nada pra mostrar e vira tela de erro.
      if (cachedData != null) {
        _data = cachedData;
        _isOffline = true;
      } else {
        _errorMessage = e.message;
      }
    } finally {
      _isLoading = false;
      _isFetching = false;
      notifyListeners();
    }
  }

  /// Melhor versão em cache do dashboard do mês: primeiro tenta reconstruir a
  /// partir das vendas/transações cacheadas (que refletem mutações feitas
  /// offline); se não houver, cai no blob congelado de [CacheKeys.dashboard].
  /// Devolve `null` se nunca houve nada cacheado.
  Future<DashboardData?> _readCachedDashboard(String? month) async {
    final rebuilt = await _buildFromLocalCache(month);
    if (rebuilt != null) return rebuilt;
    final cached = await LocalCache.instance.readObject(CacheKeys.dashboard);
    if (cached != null) return DashboardData.fromCacheJson(cached);
    return null;
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
