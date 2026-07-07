import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/reports_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/month_utils.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/async_state_view.dart';

/// Painel "Relatórios" do modo desktop: alterna entre o relatório mensal
/// (ganhos/despesas por categoria) e a comparação entre meses (gráfico de
/// barras + evolução do saldo), ambos sob o mesmo item de sidebar.
class DesktopReportsContent extends StatefulWidget {
  const DesktopReportsContent({super.key});

  @override
  State<DesktopReportsContent> createState() => _DesktopReportsContentState();
}

class _DesktopReportsContentState extends State<DesktopReportsContent> {
  bool _showComparison = false;

  late final List<String> _months = recentMonths();
  late String _selectedMonth = _months.last;

  late final List<List<String>> _intervals = threeMonthWindows(recentMonths());
  late List<String> _selectedInterval = _intervals.last;

  @override
  void initState() {
    super.initState();
    context.read<ReportsController>().loadMonthly(month: _selectedMonth);
  }

  void _onMonthChanged(String month) {
    setState(() => _selectedMonth = month);
    context.read<ReportsController>().loadMonthly(month: month);
  }

  void _onIntervalChanged(List<String> interval) {
    setState(() => _selectedInterval = interval);
    context.read<ReportsController>().loadComparison(interval);
  }

  void _onToggle(bool showComparison) {
    setState(() => _showComparison = showComparison);
    final controller = context.read<ReportsController>();
    if (showComparison && controller.comparison == null) {
      controller.loadComparison(_selectedInterval);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = Theme.of(context).extension<AppThemeExtension>();
    final positiveColor = customTheme?.positiveColor ?? Colors.green;
    final negativeColor = customTheme?.negativeColor ?? Colors.red;
    final contrastShadow = customTheme?.premiumShadow ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _showComparison ? 'Comparar meses' : 'Relatório',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _buildDropdown(),
          ],
        ),
        const SizedBox(height: 20),
        _buildToggle(),
        const SizedBox(height: 28),
        if (_showComparison)
          _buildComparisonView(positiveColor, negativeColor, contrastShadow)
        else
          _buildReportView(positiveColor, negativeColor, contrastShadow),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      width: 360,
      child: Row(
        children: [
          Expanded(
            child: _tab(
              'Relatório mensal',
              !_showComparison,
              () => _onToggle(false),
            ),
          ),
          Expanded(
            child: _tab(
              'Comparar meses',
              _showComparison,
              () => _onToggle(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: selected ? AppTheme.primaryColor : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    final field = _showComparison
        ? AppDropdownField<List<String>>(
            value: _selectedInterval,
            items: _intervals,
            labelOf: windowLabel,
            onChanged: (v) {
              if (v != null) _onIntervalChanged(v);
            },
          )
        : AppDropdownField<String>(
            value: _selectedMonth,
            items: _months,
            labelOf: monthLabel,
            onChanged: (v) {
              if (v != null) _onMonthChanged(v);
            },
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: _showComparison
              ? 'Intervalo de meses exibido no comparativo.'
              : 'Mês de referência dos dados exibidos.',
          triggerMode: TooltipTriggerMode.tap,
          child: Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.black.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(width: 6),
        field,
      ],
    );
  }

  Widget _buildReportView(
    Color positiveColor,
    Color negativeColor,
    List<BoxShadow> contrastShadow,
  ) {
    final reportsController = context.watch<ReportsController>();
    final report = reportsController.monthlyReport;

    return AsyncStateView(
      isLoading: reportsController.isLoadingMonthly,
      errorMessage: reportsController.monthlyError,
      isEmpty: report == null,
      emptyMessage: 'Nenhum dado disponível para este mês.',
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Ganhos',
                  'R\$ ${report!.ganhos.toStringAsFixed(2)}',
                  positiveColor,
                  false,
                  contrastShadow,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _statCard(
                  'Despesas',
                  'R\$ ${report.despesas.toStringAsFixed(2)}',
                  negativeColor,
                  false,
                  contrastShadow,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _statCard(
                  'Saldo do mês',
                  '${report.saldo >= 0 ? '+' : '-'} R\$ ${report.saldo.abs().toStringAsFixed(2)}',
                  report.saldo >= 0 ? positiveColor : negativeColor,
                  false,
                  contrastShadow,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _statCard(
                  'Lucro',
                  '${report.lucro >= 0 ? '+' : '-'} R\$ ${report.lucro.abs().toStringAsFixed(2)}',
                  report.lucro >= 0 ? positiveColor : negativeColor,
                  true,
                  contrastShadow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Para onde foi o dinheiro',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (report.categories.isEmpty)
            Text(
              'Nenhuma despesa registrada neste mês.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
            )
          else
            for (var i = 0; i < report.categories.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _expenseRow(
                report.categories[i].category,
                report.categories[i].value,
                negativeColor,
                report.categories[i].percentage / 100,
              ),
            ],
          const SizedBox(height: 32),
          AppButton(
            variant: AppButtonVariant.outlined,
            label: 'Exportar este mês',
            icon: Icons.share_outlined,
            onPressed: () =>
                _exportSnack('Relatório de ${monthLabel(_selectedMonth)}'),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonView(
    Color positiveColor,
    Color negativeColor,
    List<BoxShadow> contrastShadow,
  ) {
    final reportsController = context.watch<ReportsController>();
    final comparison = reportsController.comparison;

    return AsyncStateView(
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
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1.5,
                ),
                boxShadow: contrastShadow,
              ),
              child: SizedBox(
                height: 240,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: comparison.map((c) {
                    final color = c.balance >= 0
                        ? positiveColor
                        : negativeColor;
                    final height = maxAbsBalance == 0
                        ? 0.0
                        : (c.balance.abs() / maxAbsBalance) * 180.0;
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
                          duration: const Duration(milliseconds: 500),
                          width: 48,
                          height: height,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          monthAbbrevLabel(c.month),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Saldo (ganhos - despesas)',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final c = comparison[index];
                  final color = c.balance >= 0 ? positiveColor : negativeColor;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          monthLabel(c.month),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${c.balance >= 0 ? '+' : '-'} R\$ ${c.balance.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            AppButton(
              variant: AppButtonVariant.outlined,
              label: 'Exportar comparativo',
              icon: Icons.share_outlined,
              onPressed: () =>
                  _exportSnack('Comparativo ${windowLabel(_selectedInterval)}'),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(
    String label,
    String value,
    Color color,
    bool highlighted,
    List<BoxShadow> shadow,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.primaryLightColor.withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? AppTheme.primaryColor.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: highlighted ? shadow : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.45),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expenseRow(
    String name,
    double value,
    Color color,
    double percentage,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                '- R\$ ${value.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.black.withValues(alpha: 0.05),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _exportSnack(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label exportado com sucesso!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
