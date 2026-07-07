import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../state/products_controller.dart';
import '../../state/sales_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_choice_chips.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/currency_format.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/quantity_stepper.dart';

const _paymentMethodLabels = {
  PaymentMethod.dinheiro: 'Dinheiro',
  PaymentMethod.pix: 'Pix',
  PaymentMethod.cartao: 'Cartão',
  PaymentMethod.fiado: 'Fiado',
};

/// Painel "Vendas" do modo desktop: formulário de nova venda com o total
/// destacado ao lado do título, fiel ao wireframe desktop.
class DesktopSaleContent extends StatefulWidget {
  final VoidCallback onSaved;

  const DesktopSaleContent({super.key, required this.onSaved});

  @override
  State<DesktopSaleContent> createState() => _DesktopSaleContentState();
}

class _DesktopSaleContentState extends State<DesktopSaleContent> {
  final _priceController = TextEditingController();
  String? _selectedProductId;
  bool _selectionInitialized = false;
  int _quantity = 1;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.dinheiro;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    context.read<ProductsController>().load();
  }

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

    // A venda alterou o estoque no servidor: recarrega os produtos.
    await context.read<ProductsController>().load();
    if (!mounted) return;

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
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final contrastShadow =
        Theme.of(context).extension<AppThemeExtension>()?.premiumShadow ?? [];
    final productsController = context.watch<ProductsController>();
    final products = productsController.products;
    _initializeSelection(products);

    return LoadingOverlay(
      isLoading: _isSaving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Nova venda',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLightColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: contrastShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total da venda',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'R\$ ${_totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          AsyncStateView(
            isLoading: productsController.isLoading,
            errorMessage: productsController.errorMessage,
            isEmpty: products.isEmpty,
            emptyMessage:
                'Nenhum produto cadastrado ainda. Cadastre um produto antes de registrar uma venda.',
            builder: (context) => ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppDropdownField<String>(
                    label: 'Produto',
                    tooltip: 'Produto que está sendo vendido nesta transação.',
                    value: _selectedProductId!,
                    isExpanded: true,
                    items: products.map((p) => p.id).toList(),
                    labelOf: (id) =>
                        products.firstWhere((p) => p.id == id).name,
                    onChanged: (productId) =>
                        _onProductChanged(productId, products),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                  const SizedBox(height: 32),
                  AppButton(
                    label: 'Confirmar venda',
                    isLoading: _isSaving,
                    onPressed: () => _confirmSale(products),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
