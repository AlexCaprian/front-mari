import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/dashboard_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/month_utils.dart';
import '../../core/widgets/app_choice_chips.dart';
import '../../core/widgets/app_dropdown_field.dart';
import '../../core/widgets/async_state_view.dart';
import 'desktop_transaction_content.dart';

String _formatCurrency(double value) => 'R\$ ${value.toStringAsFixed(2)}';

const _activityFilters = ['Todos', 'Ganhos', 'Despesas'];

/// Altura do seletor de mês e dos botões de ação do cabeçalho.
const _actionsHeight = 42.0;

/// O padding vertical do tema (16) não cabe em [_actionsHeight]; aqui só ele
/// é substituído, o resto do estilo continua vindo do tema.
const _compactButtonPadding = ButtonStyle(
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24)),
);

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
  DateTime? _selectedDay;

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

  /// Novo lançamento (despesa / ganho extra) — no desktop ele é um modal
  /// aberto daqui, em vez de uma aba própria na barra lateral. Ao salvar,
  /// recarrega o Início já no mês que está selecionado na tela.
  Future<void> _openTransactionDialog() async {
    final saved = await showDesktopTransactionDialog(context);
    if (saved != true || !mounted) return;
    context.read<DashboardController>().load(month: _selectedMonth);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _selectedDay = picked);
  }

  List<DashboardActivity> _filterActivities(List<DashboardActivity> activity) {
    Iterable<DashboardActivity> filtered = activity;
    switch (_activityFilter) {
      case 'Ganhos':
        filtered = filtered.where((a) => a.amount >= 0);
        break;
      case 'Despesas':
        filtered = filtered.where((a) => a.amount < 0);
        break;
    }
    final day = _selectedDay;
    if (day != null) {
      filtered = filtered.where((a) => _isSameDay(a.date, day));
    }
    return filtered.toList();
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
            // Seletor de mês e os dois botões compartilham a mesma altura
            // compacta: o SizedBox define o valor e o stretch faz os três
            // ocuparem exatamente essa altura.
            SizedBox(
              height: _actionsHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMonthDropdown(),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _openTransactionDialog,
                    style: _compactButtonPadding,
                    child: const Text('Novo lançamento'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => widget.onNavigate(2),
                    style: _compactButtonPadding,
                    child: const Text('Nova venda'),
                  ),
                ],
              ),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppChoiceChips<String>(
                  items: _activityFilters,
                  labelOf: (f) => f,
                  selected: _activityFilter,
                  onSelected: (f) => setState(() => _activityFilter = f),
                  activeColor: AppTheme.primaryColor,
                  fontSize: 13,
                ),
                const SizedBox(width: 8),
                _buildDayFilterButton(),
              ],
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

  Widget _buildDayFilterButton() {
    final hasDay = _selectedDay != null;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _pickDay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasDay
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasDay
                ? AppTheme.primaryColor
                : Colors.black.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: hasDay
                  ? AppTheme.primaryColor
                  : Colors.black.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              hasDay
                  ? '${_selectedDay!.day.toString().padLeft(2, '0')}/'
                        '${_selectedDay!.month.toString().padLeft(2, '0')}'
                  : 'Filtrar dia',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: hasDay ? AppTheme.primaryColor : Colors.black87,
              ),
            ),
            if (hasDay) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () => setState(() => _selectedDay = null),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
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
          dense: true,
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
        color: Colors.white,
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
