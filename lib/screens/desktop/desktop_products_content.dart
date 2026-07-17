import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../state/products_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/currency_format.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/product_export_button.dart';
import '../../widgets/product_import_button.dart';
import '../../widgets/quantity_stepper.dart';

/// Painel "Produtos" do modo desktop: formulário de novo produto à esquerda
/// e um resumo do estoque atual à direita.
class DesktopProductsContent extends StatefulWidget {
  const DesktopProductsContent({super.key});

  @override
  State<DesktopProductsContent> createState() => _DesktopProductsContentState();
}

class _DesktopProductsContentState extends State<DesktopProductsContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  int _stock = 0;
  bool _stockRequired = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  Product? _editingProduct;

  @override
  void initState() {
    super.initState();
    context.read<ProductsController>().load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _incrementStock() => setState(() => _stock++);

  void _decrementStock() {
    if (_stock > 0) setState(() => _stock--);
  }

  void _setStock(int value) {
    setState(() => _stock = value < 0 ? 0 : value);
  }

  void _editProduct(Product product) {
    setState(() {
      _editingProduct = product;
      _nameController.text = product.name;
      _priceController.text = formatCurrencyValue(product.price);
      _costController.text = product.cost == null
          ? ''
          : formatCurrencyValue(product.cost!);
      _stock = product.stock;
      _stockRequired = product.stockRequired;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingProduct = null;
      _stock = 0;
      _stockRequired = true;
    });
    _nameController.clear();
    _priceController.clear();
    _costController.clear();
    _formKey.currentState?.reset();
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

    setState(() => _isDeleting = true);
    final controller = context.read<ProductsController>();
    final success = await controller.delete(product.id);
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (!success) {
      _showDeleteErrorDialog(controller);
      return;
    }

    if (_editingProduct?.id == product.id) {
      _cancelEdit();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Produto "${product.name}" excluído com sucesso!'),
        backgroundColor:
            Theme.of(context).extension<AppThemeExtension>()?.positiveColor ??
            Colors.green,
      ),
    );
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
    final editingProduct = _editingProduct;
    final success = editingProduct != null
        ? await controller.update(editingProduct.id, body)
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
          editingProduct != null
              ? 'Produto "${_nameController.text}" atualizado com sucesso!'
              : 'Produto "${_nameController.text}" cadastrado com sucesso!',
        ),
        backgroundColor:
            Theme.of(context).extension<AppThemeExtension>()?.positiveColor ??
            Colors.green,
      ),
    );
    _nameController.clear();
    _priceController.clear();
    _costController.clear();
    setState(() {
      _stock = 0;
      _stockRequired = true;
      _editingProduct = null;
    });
    _formKey.currentState!.reset();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSaving || _isDeleting,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editingProduct == null ? 'Novo produto' : 'Editar produto',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (_editingProduct != null) ...[
                  AppButton(
                    variant: AppButtonVariant.outlined,
                    label: 'Cancelar',
                    onPressed: _cancelEdit,
                  ),
                  const SizedBox(width: 12),
                ],
                const ProductExportButton(),
                const SizedBox(width: 12),
                const ProductImportButton(),
                const SizedBox(width: 12),
                AppButton(
                  label: _editingProduct == null
                      ? 'Salvar produto'
                      : 'Salvar alterações',
                  icon: Icons.check,
                  isLoading: _isSaving,
                  onPressed: _saveProduct,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildForm(context)),
                const SizedBox(width: 28),
                SizedBox(width: 300, child: _buildStockPanel(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Nome do produto',
          tooltip: 'Nome do produto que aparecerá nas vendas e relatórios.',
          controller: _nameController,
          hintText: 'Ex: Feijão carioca 1kg',
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Por favor, insira o nome do produto.'
              : null,
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MoneyTextField(
                label: 'Preço de venda',
                tooltip: 'Preço cobrado do cliente por unidade do produto.',
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
        CheckboxListTile(
          value: _stockRequired,
          onChanged: (value) =>
              setState(() => _stockRequired = value ?? true),
          title: const Text(
            'Quantidade obrigatória',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: const Text(
            'Controla o estoque deste produto e exige a quantidade ao '
            'cadastrar e vender.',
          ),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppTheme.primaryColor,
        ),
        if (_stockRequired) ...[
          const SizedBox(height: 8),
          QuantityStepper(
            label: 'Quantidade em estoque',
            tooltip: 'Quantidade disponível deste produto para venda.',
            value: _stock,
            onIncrement: _incrementStock,
            onDecrement: _decrementStock,
            onChanged: _setStock,
            width: 200,
            padding: const EdgeInsets.all(6),
          ),
        ],
      ],
    );
  }

  Widget _buildStockPanel(BuildContext context) {
    final contrastShadow =
        Theme.of(context).extension<AppThemeExtension>()?.premiumShadow ?? [];
    final productsController = context.watch<ProductsController>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
          width: 1.5,
        ),
        boxShadow: contrastShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estoque atual',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          AsyncStateView(
            isLoading: productsController.isLoading,
            errorMessage: productsController.errorMessage,
            isEmpty: productsController.products.isEmpty,
            emptyMessage: 'Nenhum produto cadastrado ainda.',
            builder: (context) => Column(
              children: productsController.products
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            p.stockRequired ? '${p.stock} un.' : '—',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                              fontSize: 13,
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                            onSelected: (action) {
                              if (action == 'edit') _editProduct(p);
                              if (action == 'delete') _deleteProduct(p);
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
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
