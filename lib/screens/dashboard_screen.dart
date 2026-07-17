import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../state/dashboard_controller.dart';
import '../state/products_controller.dart';
import '../state/sales_controller.dart';
import '../state/transactions_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_choice_chips.dart';
import '../widgets/async_state_view.dart';
import '../widgets/currency_format.dart';
import '../widgets/field_label.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/product_export_button.dart';
import '../widgets/product_import_button.dart';
import '../widgets/responsive_layout.dart';
import 'welcome_screen.dart';
import 'new_sale_screen.dart';
import 'new_product_screen.dart';
import 'new_transaction_screen.dart';
import 'monthly_report_screen.dart';
import 'compare_months_screen.dart';
import 'my_data_screen.dart';
import 'desktop/desktop_shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

const _activityFilters = ['Todos', 'Ganhos', 'Despesas'];

/// Resultado do bottom sheet de filtro de "Últimas movimentações": descrições
/// selecionadas e/ou um dia específico.
class ActivityFilterResult {
  const ActivityFilterResult({required this.descriptions, required this.day});

  final Set<String> descriptions;
  final DateTime? day;
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  String _activityFilter = _activityFilters.first;
  Set<String> _selectedDescriptions = {};
  DateTime? _selectedDay;
  bool _isDeletingProduct = false;
  bool _isProcessingActivity = false;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
    if (_selectedDescriptions.isNotEmpty) {
      filtered = filtered.where(
        (a) => _selectedDescriptions.contains(a.description),
      );
    }
    final day = _selectedDay;
    if (day != null) {
      filtered = filtered.where((a) => _isSameDay(a.date, day));
    }
    return filtered.toList();
  }

  Future<void> _openActivityFilterSheet() async {
    final allActivity =
        context.read<DashboardController>().data?.activity ??
        const <DashboardActivity>[];
    final options = {for (final a in allActivity) a.description}.toList()
      ..sort();

    final result = await showModalBottomSheet<ActivityFilterResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ActivityFilterSheet(
        options: options,
        initialSelected: _selectedDescriptions,
        initialDay: _selectedDay,
      ),
    );
    if (result == null) return;
    setState(() {
      _selectedDescriptions = result.descriptions;
      _selectedDay = result.day;
    });
  }

  @override
  void initState() {
    super.initState();
    context.read<ProductsController>().load();
    context.read<DashboardController>().load();
  }

  String _formatCurrency(double value) => 'R\$ ${value.toStringAsFixed(2)}';

  String _formatActivityDate(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Hoje, $time';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}, $time';
  }

  void _editProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NewProductScreen(product: product),
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: Text(
          'Tem certeza que deseja excluir "${product.name}"? Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isDeletingProduct = true);
    final controller = context.read<ProductsController>();
    final success = await controller.delete(product.id);
    if (!mounted) return;
    setState(() => _isDeletingProduct = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produto "${product.name}" excluído com sucesso!'),
          backgroundColor:
              Theme.of(context).extension<AppThemeExtension>()?.positiveColor ??
              Colors.green,
        ),
      );
      return;
    }

    _showDeleteErrorDialog(controller);
  }

  void _showDeleteErrorDialog(ProductsController controller) {
    final isConflict = controller.actionErrorStatusCode == 409;
    final detail = controller.actionError ?? 'Erro desconhecido.';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Não foi possível excluir o produto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isConflict
                  ? 'Este produto já tem vendas registradas no histórico. '
                        'Para preservar o histórico de vendas, produtos com '
                        'vendas associadas não podem ser excluídos.'
                  : 'Ocorreu um erro ao tentar excluir o produto. Verifique '
                        'sua conexão e tente novamente.',
            ),
            const SizedBox(height: 12),
            Text(
              'Detalhe: $detail',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  String _formatSignedCurrency(double amount) =>
      '${amount >= 0 ? '+' : '-'} ${_formatCurrency(amount.abs())}';

  Future<void> _editActivityValue(DashboardActivity activity) async {
    final customTheme = Theme.of(context).extension<AppThemeExtension>();
    final activeColor = activity.amount >= 0
        ? (customTheme?.positiveColor ?? Colors.green)
        : (customTheme?.negativeColor ?? Colors.red);

    final newValue = await showDialog<double>(
      context: context,
      builder: (dialogContext) => _EditActivityValueDialog(
        activity: activity,
        activeColor: activeColor,
      ),
    );

    if (newValue == null) return;
    if (!mounted) return;

    setState(() => _isProcessingActivity = true);
    bool success;
    String? actionError;
    if (activity.kind == 'sale') {
      final controller = context.read<SalesController>();
      final quantity = activity.quantity ?? 1;
      success = await controller.update(activity.id, {
        'unitPrice': newValue / quantity,
      });
      actionError = controller.actionError;
    } else {
      final controller = context.read<TransactionsController>();
      success = await controller.update(activity.id, {'amount': newValue});
      actionError = controller.actionError;
    }
    if (!mounted) return;
    setState(() => _isProcessingActivity = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actionError ?? 'Não foi possível salvar o novo valor.'),
        ),
      );
      return;
    }

    await context.read<DashboardController>().load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Valor atualizado com sucesso!'),
        backgroundColor: activeColor,
      ),
    );
  }

  Future<void> _deleteActivity(DashboardActivity activity) async {
    final customTheme = Theme.of(context).extension<AppThemeExtension>();
    final positiveColor = customTheme?.positiveColor ?? Colors.green;
    final negativeColor = customTheme?.negativeColor ?? Colors.red;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir movimentação?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tem certeza que deseja excluir esta movimentação? Essa ação não pode ser desfeita.',
            ),
            const SizedBox(height: 12),
            Text(
              activity.description,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              _formatSignedCurrency(activity.amount),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: activity.amount >= 0 ? positiveColor : negativeColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isProcessingActivity = true);
    bool success;
    String? actionError;
    if (activity.kind == 'sale') {
      final controller = context.read<SalesController>();
      success = await controller.delete(activity.id);
      actionError = controller.actionError;
    } else {
      final controller = context.read<TransactionsController>();
      success = await controller.delete(activity.id);
      actionError = controller.actionError;
    }
    if (!mounted) return;
    setState(() => _isProcessingActivity = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actionError ?? 'Não foi possível excluir a movimentação.',
          ),
        ),
      );
      return;
    }

    await context.read<DashboardController>().load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Movimentação excluída com sucesso!'),
        backgroundColor: positiveColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileBuilder: (context) => _buildMobileScaffold(context),
      desktopBuilder: (context) => const DesktopShell(),
    );
  }

  Widget _buildMobileScaffold(BuildContext context) {
    final customTheme = Theme.of(context).extension<AppThemeExtension>();
    final positiveColor = customTheme?.positiveColor ?? Colors.green;
    final negativeColor = customTheme?.negativeColor ?? Colors.red;
    final contrastShadow = customTheme?.premiumShadow ?? [];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 0,
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            // Aba 0: Início
            _buildInicioPage(positiveColor, negativeColor, contrastShadow),

            // Aba 1: Produtos (Funcional!)
            _buildProdutosPage(contrastShadow),

            // Aba 2: Relatórios (Funcional!)
            _buildRelatoriosPage(contrastShadow),

            // Aba 3: Mais (Funcional!)
            _buildMaisPage(contrastShadow),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: Colors.black.withValues(alpha: 0.4),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Início',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Produtos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Relatórios',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_outlined),
              activeIcon: Icon(Icons.more_horiz),
              label: 'Mais',
            ),
          ],
        ),
      ),
    );
  }

  /// Aba 0: Início (Abordagem 1b)
  Widget _buildInicioPage(
    Color positiveColor,
    Color negativeColor,
    List<BoxShadow> contrastShadow,
  ) {
    final dashboardController = context.watch<DashboardController>();
    final data = dashboardController.data;
    final accountName = context.watch<AuthController>().account?.name;
    final avatarInitial = accountName != null && accountName.isNotEmpty
        ? accountName[0].toUpperCase()
        : '?';
    return LoadingOverlay(
      isLoading: _isProcessingActivity,
      child: RefreshIndicator(
        onRefresh: () => context.read<DashboardController>().load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho: "Meu dinheiro" + Avatar "M"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Meu dinheiro',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.logout_rounded,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        onPressed: _showLogoutDialog,
                        tooltip: 'Sair',
                      ),
                      const SizedBox(width: 4),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          avatarInitial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (dashboardController.isOffline) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 18,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sem conexão — mostrando os últimos dados salvos.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Cartão de Saldo Destacado (Fundo Escuro Premium)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E0E3D),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: contrastShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo do mês',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(data?.saldoDoMes ?? 0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 36,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Ganhos e Despesas lado a lado dentro do cartão escuro
                    Row(
                      children: [
                        // Coluna de Ganhos
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ganhos',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(data?.ganhos ?? 0),
                                  style: TextStyle(
                                    color: positiveColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Coluna de Despesas
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Despesas',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(data?.despesas ?? 0),
                                  style: TextStyle(
                                    color: negativeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Ações Rápidas (3 Blocos Lado a Lado: Venda, Despesa, Produto)
              Row(
                children: [
                  _buildQuickActionButton(
                    icon: Icons.point_of_sale,
                    label: 'Venda',
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (context) => const NewSaleScreen(),
                            ),
                          )
                          .then((_) {
                            if (!mounted) return;
                            context.read<DashboardController>().load();
                          });
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildQuickActionButton(
                    icon: Icons.add_card,
                    label: 'Lançamentos',
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NewTransactionScreen(),
                            ),
                          )
                          .then((_) {
                            if (!mounted) return;
                            context.read<DashboardController>().load();
                          });
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildQuickActionButton(
                    icon: Icons.inventory_2_outlined,
                    label: 'Produto',
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const NewProductScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Seção "Últimas movimentações"
              Text(
                'Últimas movimentações',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppChoiceChips<String>(
                      items: _activityFilters,
                      labelOf: (f) => f,
                      selected: _activityFilter,
                      onSelected: (f) => setState(() => _activityFilter = f),
                      activeColor: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildActivityFilterButton(),
                ],
              ),
              const SizedBox(height: 16),

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
                    builder: (context) => Column(
                      children: [
                        for (var i = 0; i < activity.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final isPositive = activity[i].amount >= 0;
                              final color = isPositive
                                  ? positiveColor
                                  : negativeColor;
                              return _buildTodayTransactionItem(
                                activity: activity[i],
                                icon: isPositive
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                iconColor: color,
                                title: activity[i].description,
                                subtitle: _formatActivityDate(activity[i].date),
                                value:
                                    '${isPositive ? '+' : '-'} ${_formatCurrency(activity[i].amount.abs())}',
                                valueColor: color,
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Aba 1: Produtos (Funcional)
  Widget _buildProdutosPage(List<BoxShadow> contrastShadow) {
    final productsController = context.watch<ProductsController>();
    return LoadingOverlay(
      isLoading: _isDeletingProduct,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () => context.read<ProductsController>().load(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Produtos',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const ProductImportButton(),
                    const ProductExportButton(),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const NewProductScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Novo'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Gerencie os preços de venda e quantidade de estoque de seus itens.',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                // Listagem de produtos
                AsyncStateView(
                  isLoading: productsController.isLoading,
                  errorMessage: productsController.errorMessage,
                  isEmpty: productsController.products.isEmpty,
                  emptyMessage: 'Nenhum produto cadastrado ainda.',
                  builder: (context) => Container(
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
                      itemCount: productsController.products.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = productsController.products[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLightColor.withValues(
                                alpha: 0.3,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              product.stockRequired
                                  ? 'Estoque: ${product.stock} un.'
                                  : 'Sem controle de estoque',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'R\$ ${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _editProduct(product);
                                  }
                                  if (action == 'delete') {
                                    _deleteProduct(product);
                                  }
                                },
                                itemBuilder: (context) {
                                  final negativeColor =
                                      Theme.of(context)
                                          .extension<AppThemeExtension>()
                                          ?.negativeColor ??
                                      Colors.red;
                                  return [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                            color: Colors.black87,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Editar',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                            color: negativeColor,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Excluir',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: negativeColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ];
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Aba 2: Relatórios (Funcional)
  Widget _buildRelatoriosPage(List<BoxShadow> contrastShadow) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Relatórios',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Acompanhe seu desempenho financeiro, controle de gastos e histórico.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // Card 1: Relatório Mensal (Tela 1g)
            _buildReportNavigationCard(
              title: 'Relatório Mensal',
              description:
                  'Ganhos vs Despesas detalhadas por categoria do mês atual.',
              icon: Icons.assignment_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MonthlyReportScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Card 2: Comparar Meses (Tela 1h)
            _buildReportNavigationCard(
              title: 'Comparar Meses',
              description:
                  'Gráfico evolutivo de barras comparando os últimos períodos de saldo.',
              icon: Icons.bar_chart_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CompareMonthsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Aba 3: Mais (Funcional)
  Widget _buildMaisPage(List<BoxShadow> contrastShadow) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mais',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),

            // Lista de Opções da Aba Mais
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Opção Meus Dados (Tela 1i)
                  ListTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MyDataScreen(),
                        ),
                      );
                    },
                    leading: const Icon(
                      Icons.cloud_done_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    title: const Text(
                      'Meus dados (Backup / Arquivos)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                  const Divider(height: 1),

                  // Opção Sobre o App
                  ListTile(
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'BabyBox - Mari',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© 2026 BabyBox Inc.',
                        applicationIcon: const Text(
                          'R\$',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      );
                    },
                    leading: const Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: const Text(
                      'Sobre o BabyBox',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                  const Divider(height: 1),

                  // Opção Logout
                  ListTile(
                    onTap: _showLogoutDialog,
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Sair da conta',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportNavigationCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.08),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLightColor.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withValues(alpha: 0.45),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityFilterButton() {
    final hasFilter =
        _selectedDescriptions.isNotEmpty || _selectedDay != null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: hasFilter
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          shape: CircleBorder(
            side: BorderSide(
              color: hasFilter
                  ? AppTheme.primaryColor
                  : Colors.black.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: IconButton(
            onPressed: _openActivityFilterSheet,
            tooltip: 'Filtrar movimentações',
            icon: Icon(
              Icons.filter_alt_outlined,
              color: hasFilter
                  ? AppTheme.primaryColor
                  : Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ),
        if (hasFilter)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.08),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLightColor.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayTransactionItem({
    required DashboardActivity activity,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
    required Color valueColor,
  }) {
    final negativeColor =
        Theme.of(context).extension<AppThemeExtension>()?.negativeColor ??
        Colors.red;

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 4, top: 8, bottom: 8),
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
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Colors.black.withValues(alpha: 0.4),
              size: 20,
            ),
            onSelected: (action) {
              if (action == 'edit') _editActivityValue(activity);
              if (action == 'delete') _deleteActivity(activity);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20, color: Colors.black87),
                    SizedBox(width: 12),
                    Text('Alterar valor', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: negativeColor),
                    const SizedBox(width: 12),
                    Text(
                      'Excluir',
                      style: TextStyle(fontSize: 16, color: negativeColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    final authController = context.read<AuthController>();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Sair do Aplicativo?'),
          content: const Text(
            'Você precisará informar seu código de acesso novamente para entrar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await authController.logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              },
              child: const Text('Sair', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class _ActivityFilterSheet extends StatefulWidget {
  const _ActivityFilterSheet({
    required this.options,
    required this.initialSelected,
    required this.initialDay,
  });

  final List<String> options;
  final Set<String> initialSelected;
  final DateTime? initialDay;

  @override
  State<_ActivityFilterSheet> createState() => _ActivityFilterSheetState();
}

class _ActivityFilterSheetState extends State<_ActivityFilterSheet> {
  late final Set<String> _selected = Set.of(widget.initialSelected);
  late DateTime? _day = widget.initialDay;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredOptions = _query.isEmpty
        ? widget.options
        : widget.options
              .where((o) => o.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtrar movimentações',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_selected.isNotEmpty || _day != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _selected.clear();
                      _day = null;
                    }),
                    child: const Text('Limpar'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const FieldLabel(text: 'Dia'),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _day ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('pt', 'BR'),
                );
                if (picked != null) setState(() => _day = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _day != null
                        ? AppTheme.primaryColor
                        : Colors.black.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: _day != null
                          ? AppTheme.primaryColor
                          : Colors.black.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _day == null
                            ? 'Qualquer dia'
                            : '${_day!.day.toString().padLeft(2, '0')}/'
                                  '${_day!.month.toString().padLeft(2, '0')}/'
                                  '${_day!.year}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _day != null
                              ? AppTheme.primaryColor
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (_day != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _day = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Pesquisar...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: widget.options.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Nenhuma movimentação registrada ainda.'),
                    )
                  : filteredOptions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Nenhum item encontrado.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredOptions.length,
                      itemBuilder: (context, index) {
                        final option = filteredOptions[index];
                        return CheckboxListTile(
                          value: _selected.contains(option),
                          title: Text(option),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppTheme.primaryColor,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selected.add(option);
                              } else {
                                _selected.remove(option);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(
                  ActivityFilterResult(descriptions: _selected, day: _day),
                ),
                child: Text(
                  _selected.isEmpty && _day == null
                      ? 'Mostrar tudo'
                      : 'Aplicar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditActivityValueDialog extends StatefulWidget {
  const _EditActivityValueDialog({
    required this.activity,
    required this.activeColor,
  });

  final DashboardActivity activity;
  final Color activeColor;

  @override
  State<_EditActivityValueDialog> createState() =>
      _EditActivityValueDialogState();
}

class _EditActivityValueDialogState extends State<_EditActivityValueDialog> {
  late final TextEditingController _textController = TextEditingController(
    text: formatCurrencyValue(widget.activity.amount.abs()),
  );
  String? _errorText;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = parseCurrencyValue(_textController.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() => _errorText = 'Informe um valor válido.');
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alterar valor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.activity.description,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: widget.activeColor,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              prefixText: 'R\$ ',
              errorText: _errorText,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }
}
