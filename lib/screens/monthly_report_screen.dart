import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/reports_controller.dart';
import '../theme/app_theme.dart';
import '../utils/month_utils.dart';
import '../widgets/activity_filter.dart';
import '../widgets/app_button.dart';
import '../widgets/app_choice_chips.dart';
import '../widgets/app_dropdown_field.dart';
import '../widgets/async_state_view.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/transaction_import_button.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  late final List<String> _months = recentMonths();
  late String _selectedMonth = _months.last;
  bool _isImportingTransactions = false;
  String _activityFilter = activityTypeFilters.first;
  Set<String> _selectedDescriptions = {};
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadMonth(_selectedMonth);
  }

  void _loadMonth(String month) {
    final controller = context.read<ReportsController>();
    controller.loadMonthly(month: month);
    controller.loadMonthlyActivity(month);
  }

  void _onMonthChanged(String? month) {
    if (month == null) return;
    setState(() {
      _selectedMonth = month;
      _activityFilter = activityTypeFilters.first;
      _selectedDescriptions = {};
      _selectedDay = null;
    });
    _loadMonth(month);
  }

  Future<void> _openActivityFilterSheet(List<DashboardActivity> allActivity) async {
    final options = {for (final a in allActivity) a.description}.toList()
      ..sort();

    final result = await showActivityFilterSheet(
      context,
      options: options,
      initialSelected: _selectedDescriptions,
      initialDay: _selectedDay,
    );
    if (result == null) return;
    setState(() {
      _selectedDescriptions = result.descriptions;
      _selectedDay = result.day;
    });
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Relatório de ${monthLabel(_selectedMonth)} exportado com sucesso!',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = Theme.of(context).extension<AppThemeExtension>();
    final positiveColor = customTheme?.positiveColor ?? Colors.green;
    final negativeColor = customTheme?.negativeColor ?? Colors.red;
    final contrastShadow = customTheme?.premiumShadow ?? [];
    final reportsController = context.watch<ReportsController>();
    final report = reportsController.monthlyReport;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: _isImportingTransactions,
          message: 'Registrando dados importados...',
          child: RefreshIndicator(
            onRefresh: () async => _loadMonth(_selectedMonth),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Dropdown para escolher o mês
                  AppDropdownField<String>(
                    label: 'Mês',
                    tooltip: 'Mês de referência dos dados exibidos.',
                    value: _selectedMonth,
                    isExpanded: true,
                    items: _months,
                    labelOf: monthLabel,
                    onChanged: _onMonthChanged,
                  ),
                  const SizedBox(height: 24),

                  AsyncStateView(
                    isLoading: reportsController.isLoadingMonthly,
                    errorMessage: reportsController.monthlyError,
                    isEmpty: report == null,
                    emptyMessage: 'Nenhum dado disponível para este mês.',
                    builder: (context) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Quadro Resumo: Ganhos e Despesas lado a lado
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ganhos',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'R\$ ${report!.ganhos.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: positiveColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Despesas',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'R\$ ${report.despesas.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: negativeColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 3. Cards de Saldo e Lucro Lado a Lado
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: contrastShadow,
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Saldo do mês',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${report.saldo >= 0 ? '+' : '-'} R\$ ${report.saldo.abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: report.saldo >= 0
                                            ? positiveColor
                                            : negativeColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: contrastShadow,
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Lucro',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${report.lucro >= 0 ? '+' : '-'} R\$ ${report.lucro.abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: report.lucro >= 0
                                            ? positiveColor
                                            : negativeColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),

                        // 4. Seção "Movimentações do mês" (ganhos e despesas
                        // juntos, no mesmo formato e com os mesmos filtros
                        // usados em "Últimas movimentações" do Início)
                        Text(
                          'Movimentações do mês',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppChoiceChips<String>(
                                items: activityTypeFilters,
                                labelOf: (f) => f,
                                selected: _activityFilter,
                                onSelected: (f) =>
                                    setState(() => _activityFilter = f),
                                activeColor: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActivityFilterButton(
                              hasFilter:
                                  _selectedDescriptions.isNotEmpty ||
                                  _selectedDay != null,
                              onPressed: () => _openActivityFilterSheet(
                                reportsController.monthlyActivity ?? const [],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AsyncStateView(
                          isLoading: reportsController.isLoadingMonthlyActivity,
                          errorMessage: reportsController.monthlyActivityError,
                          isEmpty:
                              (reportsController.monthlyActivity ?? [])
                                  .isEmpty,
                          emptyMessage:
                              'Nenhuma movimentação registrada neste mês.',
                          builder: (context) {
                            final activity = filterActivityList(
                              reportsController.monthlyActivity!,
                              typeFilter: _activityFilter,
                              descriptions: _selectedDescriptions,
                              day: _selectedDay,
                            );
                            if (activity.isEmpty) {
                              return Text(
                                'Nenhuma movimentação encontrada para este filtro.',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                              );
                            }
                            return Column(
                              children: [
                                for (var i = 0; i < activity.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 12),
                                  _buildActivityItem(
                                    context: context,
                                    activity: activity[i],
                                    positiveColor: positiveColor,
                                    negativeColor: negativeColor,
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 48),

                        // 5. Importar dados / Exportar
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: TransactionImportButton(
                                onImportingChanged: (importing) => setState(
                                  () => _isImportingTransactions = importing,
                                ),
                                onImported: () => _loadMonth(_selectedMonth),
                              ),
                            ),
                            const SizedBox(height: 12),
                            AppButton(
                              variant: AppButtonVariant.outlined,
                              label: 'Exportar este mês',
                              icon: Icons.share_outlined,
                              onPressed: _exportReport,
                              fullWidth: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required BuildContext context,
    required DashboardActivity activity,
    required Color positiveColor,
    required Color negativeColor,
  }) {
    final isPositive = activity.amount >= 0;
    final color = isPositive ? positiveColor : negativeColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.06),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatExpenseDate(activity.date),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : '-'} R\$ ${activity.amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _formatExpenseDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
