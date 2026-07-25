import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/state/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../welcome_screen.dart';
import 'desktop_home_content.dart';
import 'desktop_products_content.dart';
import 'desktop_sale_content.dart';
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
  // "Despesas & ganhos" não é mais um item de navegação: virou o modal de
  // novo lançamento, aberto por um botão no Início.
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
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              // Align (em vez de só o ConstrainedBox) é o que de fato centraliza
              // a coluna de 980px na horizontal e a mantém colada no topo.
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: _buildContent(),
                ),
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
        return const DesktopReportsContent();
      case 4:
        return const DesktopDataContent();
      default:
        return DesktopHomeContent(onNavigate: _goTo);
    }
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.08,
            ), // Cor da sombra com transparência
            blurRadius: 10, // Intensidade do desfoque
            spreadRadius: 0, // Expansão da sombra
            offset: Offset(0, 0), // Deslocamento (X, Y)
          ),
        ],
      ),

      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Image.asset('assets/image/logo_color_light.png', width: 40),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Mari',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ..._navItems.asMap().entries.map(
            (entry) => _buildNavItem(entry.key, entry.value),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
            height: 2,
            width: 225,
          ),

          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showLogoutDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: Color(0xFFE65A4D),
                  ),
                  SizedBox(width: 14),
                  Text(
                    'Sair',
                    style: TextStyle(
                      color: Color(0xFFE65A4D),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _goTo(index),
        child: Stack(
          children: [
            // Barra lateral
            if (selected)
              Positioned(
                left: 0,
                top: 4,
                bottom: 4,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
              ),

            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryColor.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 20,
                    color: selected
                        ? AppTheme.primaryColor
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade700,
                      ),
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
