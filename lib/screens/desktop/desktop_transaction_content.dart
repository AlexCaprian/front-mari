import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/state/reports_controller.dart';
import '../../core/state/transactions_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/month_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_choice_chips.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/field_label.dart';
import '../../core/widgets/loading_overlay.dart';

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

/// Abre o formulário de lançamento (despesa / ganho extra) como modal do
/// modo desktop — no mobile o equivalente é a tela `NewTransactionScreen`.
/// Resolve `true` quando um lançamento foi salvo, para quem chamou poder
/// recarregar a tela de fundo.
Future<bool?> showDesktopTransactionDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    // Evita fechar sem querer no meio do preenchimento: só o X ou o
    // "Cancelar" fecham o modal.
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
          child: DesktopTransactionContent(
            onSaved: () => Navigator.of(dialogContext).pop(true),
            onCancel: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
      ),
    ),
  );
}

/// Formulário "Despesas & ganhos" do modo desktop: alternador Despesa/Ganho
/// extra, valor grande editável via teclado real e categorias. Usado dentro
/// do modal aberto por [showDesktopTransactionDialog].
class DesktopTransactionContent extends StatefulWidget {
  final VoidCallback onSaved;

  /// Quando informado, o formulário se comporta como modal: ganha o botão
  /// de fechar no cabeçalho e o "Cancelar" ao lado de salvar.
  final VoidCallback? onCancel;

  const DesktopTransactionContent({
    super.key,
    required this.onSaved,
    this.onCancel,
  });

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

  /// Na receita a categoria é escrita à mão (igual ao mobile); estes dois
  /// chips são só atalhos que preenchem o campo.
  static const List<String> _incomeCategories = ['Receita', 'Extra'];

  /// Categoria da receita: sempre o que está escrito no campo livre.
  String get _incomeCategory => _customCategoryController.text.trim();

  /// Chip de receita clicado: joga o texto no campo, que é quem vale na hora
  /// de salvar — assim dá pra usar o atalho e ainda editar depois.
  void _applyIncomeCategory(String category) {
    _customCategoryController.value = TextEditingValue(
      text: category,
      selection: TextSelection.collapsed(offset: category.length),
    );
    setState(() {});
  }

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

    // Na receita a categoria é sempre o campo livre; na despesa, só quando o
    // chip "Outro" está selecionado.
    final bool usesCustomCategory = !_isExpense || _selectedCategory == 'Outro';

    if (usesCustomCategory && _customCategoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, dê um nome para a categoria.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final categoryName = usesCustomCategory
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

    // Recarrega Relatórios em segundo plano, sem bloquear a confirmação. O
    // Início fica a cargo de quem abriu o formulário (é quem sabe qual mês
    // está selecionado lá) — um load() daqui, sem mês, ainda seria engolido
    // pelo guarda de loads sobrepostos do DashboardController.
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Novo lançamento',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (widget.onCancel != null)
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: _isSaving ? null : widget.onCancel,
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.black.withValues(alpha: 0.5),
                ),
            ],
          ),
          const SizedBox(height: 20),
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
                if (_isExpense) ...[
                  AppChoiceChips<String>(
                    label: 'Categoria',
                    tooltip:
                        'Categoria da despesa, usada para organizar os '
                        'relatórios.',
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
                ] else ...[
                  // Receita: campo livre igual ao mobile e, logo abaixo,
                  // "Receita" e "Extra" como atalhos que preenchem o campo.
                  SizedBox(
                    width: 260,
                    child: AppTextField(
                      label: 'Categoria',
                      tooltip:
                          'Categoria da receita, usada para organizar os '
                          'relatórios.',
                      controller: _customCategoryController,
                      hintText: 'Nome da categoria',
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      focusColor: activeColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppChoiceChips<String>(
                    items: _incomeCategories,
                    labelOf: (category) => category,
                    selected: _incomeCategory,
                    onSelected: _applyIncomeCategory,
                    activeColor: activeColor,
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
                // Cada botão ocupa metade da linha, então cancelar e salvar
                // têm exatamente a mesma largura.
                Row(
                  children: [
                    if (widget.onCancel != null) ...[
                      Expanded(
                        child: AppButton(
                          label: 'Cancelar',
                          onPressed: _isSaving ? null : widget.onCancel,
                          // Fundo branco com a borda na mesma cor do salvar
                          // (verde no ganho, vermelho na despesa).
                          variant: AppButtonVariant.outlined,
                          color: activeColor,
                          fullWidth: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: AppButton(
                        label: 'Salvar lançamento',
                        isLoading: _isSaving,
                        onPressed: _save,
                        color: activeColor,
                        fullWidth: true,
                      ),
                    ),
                  ],
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
