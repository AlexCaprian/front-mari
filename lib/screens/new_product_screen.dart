import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/products_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/currency_format.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/quantity_stepper.dart';

class NewProductScreen extends StatefulWidget {
  const NewProductScreen({super.key, this.product});

  /// Quando informado, a tela edita este produto em vez de criar um novo.
  final Product? product;

  @override
  State<NewProductScreen> createState() => _NewProductScreenState();
}

class _NewProductScreenState extends State<NewProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  int _stock = 0;
  bool _stockRequired = true;
  bool _isSaving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product != null) {
      _nameController.text = product.name;
      _priceController.text = formatCurrencyValue(product.price);
      _costController.text = product.cost == null
          ? ''
          : formatCurrencyValue(product.cost!);
      _stock = product.stock;
      _stockRequired = product.stockRequired;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _incrementStock() {
    setState(() {
      _stock++;
    });
  }

  void _decrementStock() {
    if (_stock > 0) {
      setState(() {
        _stock--;
      });
    }
  }

  void _setStock(int value) {
    setState(() => _stock = value < 0 ? 0 : value);
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final controller = context.read<ProductsController>();
    final body = {
      'name': _nameController.text.trim(),
      'price': parseCurrencyValue(_priceController.text)!,
      'cost': _costController.text.trim().isEmpty
          ? null
          : parseCurrencyValue(_costController.text),
      'stock': _stockRequired ? _stock : 0,
      'stockRequired': _stockRequired,
    };
    final success = _isEditing
        ? await controller.update(widget.product!.id, body)
        : await controller.create(body);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.actionError ?? 'Não foi possível salvar o produto.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Produto "${_nameController.text}" atualizado com sucesso!'
              : 'Produto "${_nameController.text}" cadastrado com sucesso!',
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
    return LoadingOverlay(
      isLoading: _isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar produto' : 'Novo produto'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Nome do Produto
                  AppTextField(
                    label: 'Nome do produto',
                    tooltip:
                        'Nome do produto que aparecerá nas vendas e relatórios.',
                    controller: _nameController,
                    hintText: 'Ex: Feijão carioca 1kg',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, insira o nome do produto.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // 2. Preço de Venda e Custo Lado a Lado
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: MoneyTextField(
                          label: 'Preço de venda',
                          tooltip:
                              'Preço cobrado do cliente por unidade do produto.',
                          controller: _priceController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Obrigatório.';
                            }
                            if (parseCurrencyValue(value) == null) {
                              return 'Inválido.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: MoneyTextField(
                          label: 'Custo (opcional)',
                          tooltip:
                              'Quanto você pagou para adquirir o produto. '
                              'Usado para calcular o lucro (preço de venda - custo) nos relatórios.',
                          controller: _costController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 3. Quantidade em Estoque (opcional)
                  CheckboxListTile(
                    value: _stockRequired,
                    onChanged: (value) =>
                        setState(() => _stockRequired = value ?? true),
                    title: const Text(
                      'Quantidade obrigatória',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: const Text(
                      'Controla o estoque deste produto e exige a quantidade '
                      'ao cadastrar e vender.',
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppTheme.primaryColor,
                  ),
                  if (_stockRequired) ...[
                    const SizedBox(height: 8),
                    QuantityStepper(
                      label: 'Quantidade em estoque',
                      tooltip:
                          'Quantidade disponível deste produto para venda.',
                      value: _stock,
                      onIncrement: _incrementStock,
                      onDecrement: _decrementStock,
                      onChanged: _setStock,
                      padding: const EdgeInsets.all(6),
                    ),
                  ],
                  const SizedBox(height: 48),

                  // 4. Botão de Salvar Produto
                  AppButton(
                    label: _isEditing ? 'Salvar alterações' : 'Salvar produto',
                    isLoading: _isSaving,
                    onPressed: _saveProduct,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
