import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../state/dashboard_controller.dart';
import '../../state/reports_controller.dart';
import '../../state/transactions_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/month_utils.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_choice_chips.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/field_label.dart';
import '../../widgets/loading_overlay.dart';

/// Formata dígitos digitados livremente como moeda em tempo real
/// (ex.: "21000" -> "210,00"), no mesmo padrão usado no teclado
/// numérico customizado da versão mobile, mas alimentado pelo teclado
/// físico/real do desktop.
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final String trimmed = digits.length > 9 ? digits.substring(0, 9) : digits;
    final double value = double.parse(trimmed) / 100;
    final String formatted = _formatCurrency(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _formatCurrency(double value) {
    final String basic = value.toStringAsFixed(2);
    final List<String> parts = basic.split('.');
    String integerPart = parts[0];
    final String decimalPart = parts[1];
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    integerPart = integerPart.replaceAllMapped(
      reg,
      (Match match) => '${match[1]}.',
    );
    return '$integerPart,$decimalPart';
  }
}

/// Painel "Despesas & ganhos" do modo desktop: alternador Despesa/Ganho
/// extra, valor grande editável via teclado real e categorias.
class DesktopTransactionContent extends StatefulWidget {
  final VoidCallback onSaved;

  const DesktopTransactionContent({super.key, required this.onSaved});

  @override
  State<DesktopTransactionContent> createState() =>
      _DesktopTransactionContentState();
}

class _DesktopTransactionContentState extends State<DesktopTransactionContent> {
  bool _isExpense = false;
  final TextEditingController _valueController = TextEditingController();
  String _selectedCategory = 'Luz';
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _customCategoryController =
      TextEditingController();
  bool _isSaving = false;

  final List<String> _categories = const [
    'Luz',
    'Água',
    'Internet',
    'Mercado',
    'Aluguel',
    'Gasolina',
    'Carro',
    'Almoço',
    'Outro',
  ];

  @override
  void dispose() {
    _valueController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  double get _amount {
    final digits = _valueController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0.0;
    return double.parse(digits) / 100;
  }

  String get _formattedDate =>
      '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira um valor válido.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (_selectedCategory == 'Outro' &&
        _customCategoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, dê um nome para a categoria.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final categoryName = _selectedCategory == 'Outro'
        ? _customCategoryController.text.trim()
        : _selectedCategory;

    setState(() => _isSaving = true);
    final controller = context.read<TransactionsController>();
    final success = await controller.create({
      'type': (_isExpense ? TransactionType.expense : TransactionType.income)
          .apiValue,
      'amount': _amount,
      'category': categoryName,
      'occurredAt': _selectedDate.toUtc().toIso8601String(),
    });

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.actionError ?? 'Não foi possível salvar o lançamento.',
          ),
        ),
      );
      return;
    }

    // Recarrega Início e Relatórios em segundo plano, sem bloquear a
    // confirmação nem a volta pro Início.
    context.read<DashboardController>().load();
    context.read<ReportsController>().loadMonthly();
    context.read<ReportsController>().loadComparison(
      threeMonthWindows(recentMonths()).last,
    );

    final type = _isExpense ? 'Despesa' : 'Receita';
    final sign = _isExpense ? '-' : '+';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$type "$categoryName" de $sign R\$ ${_valueController.text} salva com sucesso!',
        ),
        backgroundColor: _isExpense
            ? (Theme.of(
                    context,
                  ).extension<AppThemeExtension>()?.negativeColor ??
                  Colors.red)
            : (Theme.of(
                    context,
                  ).extension<AppThemeExtension>()?.positiveColor ??
                  Colors.green),
      ),
    );
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = Theme.of(context).extension<AppThemeExtension>();
    final positiveColor = customTheme?.positiveColor ?? Colors.green;
    final negativeColor = customTheme?.negativeColor ?? Colors.red;
    final activeColor = _isExpense ? negativeColor : positiveColor;
    final sign = _isExpense ? '-' : '+';

    return LoadingOverlay(
      isLoading: _isSaving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Novo lançamento',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTab(
                          'Receita',
                          !_isExpense,
                          positiveColor,
                          () => setState(() => _isExpense = false),
                        ),
                      ),
                      Expanded(
                        child: _buildTab(
                          'Despesa',
                          _isExpense,
                          negativeColor,
                          () => setState(() => _isExpense = true),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FieldLabel(
                  text: 'Valor',
                  tooltip: 'Valor da despesa ou ganho extra a ser lançado.',
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$sign R\$ ',
                      style: TextStyle(
                        color: activeColor,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _valueController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        style: TextStyle(
                          color: activeColor,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0,00',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 40),
                AppChoiceChips<String>(
                  label: 'Categoria',
                  tooltip:
                      'Categoria da despesa ou ganho extra, usada para '
                      'organizar os relatórios.',
                  items: _categories,
                  labelOf: (category) => category,
                  selected: _selectedCategory,
                  onSelected: (category) =>
                      setState(() => _selectedCategory = category),
                  activeColor: activeColor,
                ),
                if (_selectedCategory == 'Outro') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 260,
                    child: AppTextField(
                      label: 'Nome da categoria',
                      tooltip:
                          'Nome da categoria personalizada, usado quando '
                          'nenhuma das opções acima se aplica.',
                      controller: _customCategoryController,
                      hintText: 'Nome da categoria',
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      focusColor: activeColor,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FieldLabel(
                  text: 'Data',
                  tooltip: 'Data em que a despesa ou ganho ocorreu.',
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.12),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formattedDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: 'Salvar lançamento',
                  isLoading: _isSaving,
                  onPressed: _save,
                  color: activeColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    String label,
    bool selected,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
