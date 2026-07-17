import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/dashboard_controller.dart';
import '../state/reports_controller.dart';
import '../state/transactions_controller.dart';
import '../theme/app_theme.dart';
import '../utils/month_utils.dart';
import '../widgets/app_button.dart';
import '../widgets/app_choice_chips.dart';
import '../widgets/app_text_field.dart';
import '../widgets/field_label.dart';
import '../widgets/loading_overlay.dart';

class NewTransactionScreen extends StatefulWidget {
  final bool isExpenseInitial; // Define se abre inicialmente como Despesa

  const NewTransactionScreen({super.key, this.isExpenseInitial = false});

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen> {
  late bool _isExpense;
  String _digits =
      ''; // Acumula os dígitos digitados para o valor de ponto fixo (ex: 21000 = 210,00)
  String _selectedCategory = 'Luz';
  final TextEditingController _customCategoryController =
      TextEditingController();

  final List<String> _categories = [
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

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isExpense = widget.isExpenseInitial;
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    super.dispose();
  }

  // Formata o valor digitado como moeda real R$
  String get _formattedValue {
    if (_digits.isEmpty) {
      return '0,00';
    }
    final double parsed = double.parse(_digits) / 100;

    // Formata o número com 2 casas decimais e substitui ponto por vírgula
    final String basic = parsed.toStringAsFixed(2);
    final List<String> parts = basic.split('.');

    // Adiciona separador de milhar se necessário
    String integerPart = parts[0];
    final String decimalPart = parts[1];

    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    integerPart = integerPart.replaceAllMapped(
      reg,
      (Match match) => '${match[1]}.',
    );

    return '$integerPart,$decimalPart';
  }

  void _onKeyPress(String key) {
    setState(() {
      if (key == 'backspace') {
        if (_digits.isNotEmpty) {
          _digits = _digits.substring(0, _digits.length - 1);
        }
      } else if (key == ',') {
        // No teclado financeiro de ponto fixo, a vírgula pode simular a inserção de centavos (ex: adiciona dois zeros)
        if (_digits.isNotEmpty && !_digits.endsWith('00')) {
          _digits += '00';
        }
      } else {
        // Evita estouro de limite de dígitos
        if (_digits.length < 8) {
          // Se for o primeiro dígito e for '0', ignora
          if (_digits.isEmpty && key == '0') return;
          _digits += key;
        }
      }
    });
  }

  Future<void> _saveTransaction() async {
    if (_digits.isEmpty || _digits == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira um valor válido.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final needsCustomCategory = !_isExpense || _selectedCategory == 'Outro';

    if (needsCustomCategory && _customCategoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, dê um nome para a categoria.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final categoryName = needsCustomCategory
        ? _customCategoryController.text.trim()
        : _selectedCategory;

    setState(() => _isSaving = true);
    final controller = context.read<TransactionsController>();
    final success = await controller.create({
      'type': (_isExpense ? TransactionType.expense : TransactionType.income)
          .apiValue,
      'amount': double.parse(_digits) / 100,
      'category': categoryName,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
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

    // O lançamento alterou o saldo do dia, o relatório mensal e o
    // comparativo de meses (janela mais recente, que inclui o mês atual).
    // Dispara em segundo plano, sem bloquear a confirmação nem a volta pro
    // Início — o próprio Início já escuta esses controllers e se atualiza
    // sozinho assim que a resposta chegar.
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
          '$type "$categoryName" de $sign R\$ $_formattedValue salva com sucesso!',
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
    Navigator.of(context).pop();
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
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('Novo lançamento'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Corpo com scroll para a parte de cima, deixando o teclado fixo na parte inferior
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Alternador Despesa / Ganho Extra
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            // Tab Ganho
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isExpense = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_isExpense
                                        ? positiveColor
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Receita',
                                      style: TextStyle(
                                        color: !_isExpense
                                            ? Colors.white
                                            : Colors.black54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Tab Despesa
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isExpense = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isExpense
                                        ? negativeColor
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Despesa',
                                      style: TextStyle(
                                        color: _isExpense
                                            ? Colors.white
                                            : Colors.black54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 2. Painel do Valor Grande (Cor muda conforme despesa/ganho)
                      FieldLabel(
                        text: 'Valor',
                        tooltip:
                            'Valor da despesa ou ganho extra a ser lançado.',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$sign R\$ $_formattedValue',
                        style: TextStyle(
                          color: activeColor,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 3. Categoria: para Ganho extra é sempre um input livre;
                      // para Despesa é o grid de chips (com input quando "Outro").
                      if (_isExpense) ...[
                        if (_selectedCategory == 'Outro') ...[
                          AppTextField(
                            label: 'Nome da categoria',
                            tooltip:
                                'Nome da categoria personalizada, usado quando '
                                'nenhuma das opções acima se aplica.',
                            controller: _customCategoryController,
                            hintText: 'Nome da categoria',
                            textCapitalization: TextCapitalization.sentences,
                            autofocus: true,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            focusColor: activeColor,
                          ),
                          const SizedBox(height: 16),
                        ],
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
                      ] else
                        AppTextField(
                          label: 'Categoria',
                          tooltip:
                              'Categoria do ganho extra, usada para organizar '
                              'os relatórios.',
                          controller: _customCategoryController,
                          hintText: 'Nome da categoria',
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          focusColor: activeColor,
                        ),
                    ],
                  ),
                ),
              ),

              // Teclado Numérico Customizado + Botão Salvar (Fixo embaixo)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    // Teclado Numérico
                    _buildKeyboard(),
                    const SizedBox(height: 16),
                    // Botão Salvar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: AppButton(
                        label: 'Salvar',
                        isLoading: _isSaving,
                        onPressed: _saveTransaction,
                        color: activeColor,
                        fullWidth: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Constrói a tabela/grid do teclado numérico
  Widget _buildKeyboard() {
    final List<List<String>> keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [',', '0', 'backspace'],
    ];

    return Table(
      children: keys.map((row) {
        return TableRow(
          children: row.map((key) {
            return _buildKeyButton(key);
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildKeyButton(String key) {
    Widget child;
    if (key == 'backspace') {
      child = const Icon(
        Icons.backspace_outlined,
        color: Colors.black87,
        size: 22,
      );
    } else {
      child = Text(
        key,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(key),
        child: Container(height: 54, alignment: Alignment.center, child: child),
      ),
    );
  }
}
