import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/dashboard_controller.dart';
import '../state/products_controller.dart';
import '../state/reports_controller.dart';
import '../state/sales_controller.dart';
import '../theme/app_theme.dart';
import '../utils/month_utils.dart';
import '../widgets/app_button.dart';
import '../widgets/app_choice_chips.dart';
import '../widgets/app_dropdown_field.dart';
import '../widgets/app_text_field.dart';
import '../widgets/async_state_view.dart';
import '../widgets/currency_format.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/quantity_stepper.dart';

const _paymentMethodLabels = {
  PaymentMethod.dinheiro: 'Dinheiro',
  PaymentMethod.pix: 'Pix',
  PaymentMethod.cartao: 'Cartão',
  PaymentMethod.fiado: 'Fiado',
};

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final _priceController = TextEditingController();
  String? _selectedProductId;
  bool _selectionInitialized = false;
  int _quantity = 1;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.dinheiro;
  bool _isSaving = false;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _initializeSelection(List<Product> products) {
    if (_selectionInitialized || products.isEmpty) return;
    _selectionInitialized = true;
    _selectedProductId = products.first.id;
    _priceController.text = formatCurrencyValue(products.first.price);
  }

  double get _unitPrice => parseCurrencyValue(_priceController.text) ?? 0.0;

  double get _totalPrice => _unitPrice * _quantity;

  void _onProductChanged(String? productId, List<Product> products) {
    if (productId == null) return;
    final product = products.firstWhere((p) => p.id == productId);
    setState(() {
      _selectedProductId = productId;
      _priceController.text = formatCurrencyValue(product.price);
    });
  }

  void _incrementQuantity() => setState(() => _quantity++);

  void _decrementQuantity() {
    if (_quantity > 1) setState(() => _quantity--);
  }

  void _setQuantity(int value) {
    setState(() => _quantity = value < 1 ? 1 : value);
  }

  Future<void> _confirmSale(List<Product> products) async {
    final productId = _selectedProductId;
    if (productId == null) return;

    setState(() => _isSaving = true);
    final salesController = context.read<SalesController>();
    final success = await salesController.create({
      'productId': productId,
      'quantity': _quantity,
      'unitPrice': _unitPrice,
      'paymentMethod': _selectedPaymentMethod.apiValue,
    });

    if (!mounted) return;

    if (!success) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            salesController.actionError ??
                'Não foi possível registrar a venda.',
          ),
        ),
      );
      return;
    }

    // A venda alterou o estoque, o saldo do dia, o relatório mensal e o
    // comparativo de meses. Dispara em segundo plano, sem bloquear a
    // confirmação nem a volta pra tela anterior — cada tela já escuta seu
    // controller e se atualiza sozinha assim que a resposta chegar.
    context.read<ProductsController>().load();
    context.read<DashboardController>().load();
    context.read<ReportsController>().loadMonthly();
    context.read<ReportsController>().loadComparison(
      threeMonthWindows(recentMonths()).last,
    );

    final productName = products.firstWhere((p) => p.id == productId).name;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Venda de $_quantity x $productName realizada com sucesso!',
        ),
        backgroundColor:
            Theme.of(context).extension<AppThemeExtension>()?.positiveColor ??
            Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = Theme.of(context).extension<AppThemeExtension>();
    final contrastShadow = customTheme?.premiumShadow ?? [];
    final productsController = context.watch<ProductsController>();
    final products = productsController.products;
    _initializeSelection(products);

    return LoadingOverlay(
      isLoading: _isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nova venda'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => context.read<ProductsController>().load(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: AsyncStateView(
                isLoading: productsController.isLoading,
                errorMessage: productsController.errorMessage,
                isEmpty: products.isEmpty,
                emptyMessage:
                    'Nenhum produto cadastrado ainda. Cadastre um produto antes de registrar uma venda.',
                padding: const EdgeInsets.all(24.0),
                builder: (context) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 24.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Dropdown de Seleção de Produto
                      AppDropdownField<String>(
                        label: 'Produto',
                        tooltip:
                            'Produto que está sendo vendido nesta transação.',
                        value: _selectedProductId!,
                        isExpanded: true,
                        items: products.map((p) => p.id).toList(),
                        labelOf: (id) =>
                            products.firstWhere((p) => p.id == id).name,
                        onChanged: (productId) =>
                            _onProductChanged(productId, products),
                      ),
                      const SizedBox(height: 24),

                      // 2. Quantidade e Preço Unitário Lado a Lado
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Campo Quantidade
                          Expanded(
                            child: QuantityStepper(
                              label: 'Quantidade',
                              tooltip:
                                  'Quantidade de unidades vendidas nesta venda.',
                              value: _quantity,
                              onIncrement: _incrementQuantity,
                              onDecrement: _decrementQuantity,
                              onChanged: _setQuantity,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Campo Preço Unitário
                          Expanded(
                            child: MoneyTextField(
                              label: 'Preço unit.',
                              tooltip:
                                  'Preço por unidade nesta venda. Vem preenchido '
                                  'com o preço cadastrado do produto, mas pode ser '
                                  'ajustado (ex: desconto).',
                              controller: _priceController,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 3. Forma de Pagamento (Chips)
                      AppChoiceChips<PaymentMethod>(
                        label: 'Forma de pagamento',
                        tooltip: 'Como o cliente pagou por esta venda.',
                        items: PaymentMethod.values,
                        labelOf: (method) => _paymentMethodLabels[method]!,
                        selected: _selectedPaymentMethod,
                        onSelected: (method) =>
                            setState(() => _selectedPaymentMethod = method),
                        activeColor: AppTheme.primaryColor,
                        fontSize: 15,
                      ),
                      const SizedBox(height: 48),

                      // 4. Box de Total da Venda
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLightColor.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: contrastShadow,
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Total da venda',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'R\$ ${_totalPrice.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),

                      // 5. Botão Confirmar
                      AppButton(
                        label: 'Confirmar venda',
                        isLoading: _isSaving,
                        onPressed: () => _confirmSale(products),
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
