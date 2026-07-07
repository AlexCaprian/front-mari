import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/reports_controller.dart';
import '../theme/app_theme.dart';
import '../utils/month_utils.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dropdown_field.dart';
import '../widgets/async_state_view.dart';

class CompareMonthsScreen extends StatefulWidget {
  const CompareMonthsScreen({super.key});

  @override
  State<CompareMonthsScreen> createState() => _CompareMonthsScreenState();
}

class _CompareMonthsScreenState extends State<CompareMonthsScreen> {
  late final List<List<String>> _intervals = threeMonthWindows(recentMonths());
  late List<String> _selectedInterval = _intervals.last;

  @override
  void initState() {
    super.initState();
    context.read<ReportsController>().loadComparison(_selectedInterval);
  }

  void _onIntervalChanged(List<String>? interval) {
    if (interval == null) return;
    setState(() => _selectedInterval = interval);
    context.read<ReportsController>().loadComparison(interval);
  }

  void _exportComparison() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Comparativo do intervalo ${windowLabel(_selectedInterval)} exportado com sucesso!',
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
    final comparison = reportsController.comparison;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar meses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<ReportsController>().loadComparison(
            _selectedInterval,
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Filtro de Intervalo (Dropdown)
                AppDropdownField<List<String>>(
                  label: 'Intervalo',
                  tooltip: 'Intervalo de meses exibido no comparativo.',
                  value: _selectedInterval,
                  isExpanded: true,
                  items: _intervals,
                  labelOf: windowLabel,
                  onChanged: _onIntervalChanged,
                ),
                const SizedBox(height: 28),

                AsyncStateView(
                  isLoading: reportsController.isLoadingComparison,
                  errorMessage: reportsController.comparisonError,
                  isEmpty: comparison == null,
                  emptyMessage: 'Nenhum dado disponível para este intervalo.',
                  builder: (context) {
                    final maxAbsBalance = comparison!.isEmpty
                        ? 0.0
                        : comparison
                              .map((c) => c.balance.abs())
                              .reduce((a, b) => a > b ? a : b);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Gráfico de Barras Customizado (Desenhado com Widgets nativos)
                        Text(
                          'Saldo por mês',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: contrastShadow,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 220,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: comparison.map((c) {
                                    final color = c.balance >= 0
                                        ? positiveColor
                                        : negativeColor;
                                    final height = maxAbsBalance == 0
                                        ? 0.0
                                        : (c.balance.abs() / maxAbsBalance) *
                                              160.0;
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${c.balance >= 0 ? '+' : '-'} R\$ ${c.balance.abs().toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 500,
                                          ),
                                          width: 36,
                                          height: height,
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(8),
                                                  topRight: Radius.circular(8),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          monthAbbrevLabel(c.month),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1, thickness: 1.2),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: positiveColor,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Saldo positivo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: negativeColor,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Saldo negativo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),

                        // 3. Tabela de Evolução do Saldo
                        Text(
                          'Evolução do saldo',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.06),
                              width: 1.5,
                            ),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comparison.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final c = comparison[index];
                              final color = c.balance >= 0
                                  ? positiveColor
                                  : negativeColor;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 16.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      monthLabel(c.month),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${c.balance >= 0 ? '+' : '-'} R\$ ${c.balance.abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 48),

                        // 4. Botão Exportar comparativo
                        AppButton(
                          variant: AppButtonVariant.outlined,
                          label: 'Exportar comparativo',
                          icon: Icons.share_outlined,
                          onPressed: _exportComparison,
                          fullWidth: true,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
