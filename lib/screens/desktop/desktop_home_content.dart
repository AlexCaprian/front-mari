import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/dashboard_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/month_utils.dart';
import '../../widgets/app_choice_chips.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/async_state_view.dart';

String _formatCurrency(double value) => 'R\$ ${value.toStringAsFixed(2)}';

const _activityFilters = ['Todos', 'Ganhos', 'Despesas'];

/// Painel "Início" do modo desktop: saudação, cartões de resumo do mês e a
/// tabela de últimas movimentações (Descrição / Categoria / Data / Valor).
class DesktopHomeContent extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const DesktopHomeContent({super.key, required this.onNavigate});

  @override
  State<DesktopHomeContent> createState() => _DesktopHomeContentState();
}

class _DesktopHomeContentState extends State<DesktopHomeContent> {
  late final List<String> _months = recentMonths();
  late String _selectedMonth = _months.last;
  String _activityFilter = _activityFilters.first;

  @override
  void initState() {
    super.initState();
    context.read<DashboardController>().load(month: _selectedMonth);
  }

  void _onMonthChanged(String? month) {
    if (month == null) return;
    setState(() => _selectedMonth = month);
    context.read<DashboardController>().load(month: month);
  }

  List<DashboardActivity> _filterActivities(List<DashboardActivity> activity) {
    switch (_activityFilter) {
      case 'Ganhos':
        return activity.where((a) => a.amount >= 0).toList();
      case 'Despesas':
        return activity.where((a) => a.amount < 0).toList();
      default:
        return activity;
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = Theme.of(context).extension<AppThemeExtension>();
    final positiveColor = customTheme?.positiveColor ?? Colors.green;
    final negativeColor = customTheme?.negativeColor ?? Colors.red;
    final contrastShadow = customTheme?.premiumShadow ?? [];
    final dashboardController = context.watch<DashboardController>();
    final data = dashboardController.data;
    final accountName = context.watch<AuthController>().account?.name;
    final greeting = accountName != null && accountName.isNotEmpty
        ? 'Olá, $accountName'
        : 'Olá';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                greeting,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _buildMonthDropdown(),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => widget.onNavigate(3),
              child: const Text('Nova despesa'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => widget.onNavigate(2),
              child: const Text('Nova venda'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Saldo do mês',
                value: _formatCurrency(data?.saldoDoMes ?? 0),
                highlighted: true,
                shadow: contrastShadow,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                label: 'Ganhos',
                value: _formatCurrency(data?.ganhos ?? 0),
                valueColor: positiveColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                label: 'Despesas',
                value: _formatCurrency(data?.despesas ?? 0),
                valueColor: negativeColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Últimas movimentações',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            AppChoiceChips<String>(
              items: _activityFilters,
              labelOf: (f) => f,
              selected: _activityFilter,
              onSelected: (f) => setState(() => _activityFilter = f),
              activeColor: AppTheme.primaryColor,
              fontSize: 13,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTransactionsTable(
          dashboardController,
          data,
          positiveColor,
          negativeColor,
        ),
      ],
    );
  }

  Widget _buildMonthDropdown() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Mês de referência dos dados exibidos.',
          triggerMode: TooltipTriggerMode.tap,
          child: Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.black.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(width: 6),
        AppDropdownField<String>(
          value: _selectedMonth,
          items: _months,
          labelOf: monthLabel,
          onChanged: _onMonthChanged,
        ),
      ],
    );
  }

  Widget _buildTransactionsTable(
    DashboardController dashboardController,
    DashboardData? data,
    Color positiveColor,
    Color negativeColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.06),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Descrição',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Categoria',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Data',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Valor',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Builder(
            builder: (context) {
              final activity = data == null
                  ? const <DashboardActivity>[]
                  : _filterActivities(data.activity);
              return AsyncStateView(
                isLoading: dashboardController.isLoading,
                errorMessage: dashboardController.errorMessage,
                isEmpty: activity.isEmpty,
                emptyMessage: data == null || data.activity.isEmpty
                    ? 'Nenhuma movimentação registrada ainda.'
                    : 'Nenhuma movimentação encontrada para este filtro.',
                padding: const EdgeInsets.all(20.0),
                builder: (context) => ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activity.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = activity[index];
                    final isPositive = item.amount >= 0;
                    final color = isPositive ? positiveColor : negativeColor;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              item.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.category,
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.55),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              formatShortDate(item.date),
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.55),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '${isPositive ? '+' : '-'} ${_formatCurrency(item.amount.abs())}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: color,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool highlighted;
  final List<BoxShadow> shadow;

  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor,
    this.highlighted = false,
    this.shadow = const [],
  });

  @override
  Widget build(BuildContext context) {
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
              color: valueColor ?? AppTheme.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}
