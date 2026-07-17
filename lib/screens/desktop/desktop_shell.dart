import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../welcome_screen.dart';
import 'desktop_home_content.dart';
import 'desktop_products_content.dart';
import 'desktop_sale_content.dart';
import 'desktop_transaction_content.dart';
import 'desktop_reports_content.dart';
import 'desktop_data_content.dart';

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}

const List<_NavItemData> _navItems = [
  _NavItemData(icon: Icons.account_balance_wallet_outlined, label: 'Início'),
  _NavItemData(icon: Icons.inventory_2_outlined, label: 'Produtos'),
  _NavItemData(icon: Icons.point_of_sale_outlined, label: 'Vendas'),
  _NavItemData(icon: Icons.swap_vert_rounded, label: 'Despesas & ganhos'),
  _NavItemData(icon: Icons.bar_chart_outlined, label: 'Relatórios'),
  _NavItemData(icon: Icons.import_export_rounded, label: 'Exportar / Importar'),
];

/// Casca fixa do modo desktop: sidebar de navegação sempre visível à
/// esquerda e um painel de conteúdo à direita que troca de acordo com o
/// item selecionado, sem empilhar novas rotas — fiel ao wireframe desktop.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  int _selectedIndex = 0;

  void _goTo(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FA),
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: _buildContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return DesktopHomeContent(onNavigate: _goTo);
      case 1:
        return const DesktopProductsContent();
      case 2:
        return DesktopSaleContent(onSaved: () => _goTo(0));
      case 3:
        return DesktopTransactionContent(onSaved: () => _goTo(0));
      case 4:
        return const DesktopReportsContent();
      case 5:
        return const DesktopDataContent();
      default:
        return DesktopHomeContent(onNavigate: _goTo);
    }
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'R\$',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Mari',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ..._navItems.asMap().entries.map(
            (entry) => _buildNavItem(entry.key, entry.value),
          ),
          const Spacer(),
          const Divider(),
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showLogoutDialog,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text(
                    'Minha conta',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, _NavItemData item) {
    final bool selected = index == _selectedIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _goTo(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryLightColor.withValues(alpha: 0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? AppTheme.primaryColor : Colors.black54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected ? AppTheme.primaryColor : Colors.black87,
                      fontSize: 14,
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
